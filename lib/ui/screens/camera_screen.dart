// 카메라 프리뷰 없이(화면 가림 방지) 보드 + 시선 커서 UI
// 성능 최적화: 60fps 스로틀, 미세 이동 데드존, 리드아웃 주기 증가

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:vibration/vibration.dart';

import '../../app.dart';
import '../../core/logger.dart';
import '../../domain/gaze/calibration.dart';
import '../../domain/gaze/dwell_fsm.dart';
import '../../domain/gaze/gaze_repo.dart';
import '../../domain/gaze/mock_gaze.dart';
import '../../domain/gaze/mlkit_gaze_repo.dart';
import '../../domain/models/board_model.dart';
import '../../domain/models/card_model.dart';
import '../../domain/models/settings_model.dart';
import '../widgets/card_grid.dart';
import '../widgets/gaze_cursor.dart';
import 'sos_detail_screen.dart';

/// ✅ 누락되어 빌드 에러가 났던 포커스 링 위젯
class FocusRing extends StatelessWidget {
  final Rect rect;
  final Color color;
  final double stroke;
  final double radius;

  const FocusRing({
    super.key,
    required this.rect,
    this.color = Colors.amberAccent,
    this.stroke = 4,
    this.radius = 8,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: rect.left,
      top: rect.top,
      width: rect.width,
      height: rect.height,
      child: IgnorePointer(
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: color, width: stroke),
            borderRadius: BorderRadius.circular(radius),
            color: Colors.transparent,
          ),
        ),
      ),
    );
  }
}

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  BoardPage? _page;
  Map<String, Rect> _rects = {};
  GazeRepo? _gaze;
  StreamSubscription<GazePoint>? _gazeSub;
  Offset _cursor = const Offset(0, 0);
  bool _flash = false;
  DwellFsm _fsm = DwellFsm();
  Calibration? _calib;
  double _progress = 0.0;

  bool _inited = false;
  String? _lastHoverId;
  DateTime _lastReadout = DateTime.fromMillisecondsSinceEpoch(0);
  bool _gotGaze = false;
  Timer? _fallbackTimer;
  Timer? _heartbeat;

  // 렌더링 스로틀
  DateTime _lastRebuild = DateTime.fromMillisecondsSinceEpoch(0);
  static const _minFrameIntervalUs = (1000000 / 60); // 60fps

  // 미세 이동 데드존(화면 px가 아닌 정규화 좌표 기준 → build때 실측 변환)
  static const _deadzoneNorm = 0.0045;
  Offset? _lastDrawnPx;
  List<double>? _lastNorm;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_inited) {
      _inited = true;
      _bootstrap();
    }
  }

  @override
  void dispose() {
    _gazeSub?.cancel();
    _fallbackTimer?.cancel();
    _heartbeat?.cancel();
    try { _gaze?.stop(); } catch (_) {}
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final bundle = AppScope.of(context);
    _gaze = bundle.gaze;
    final s = SettingsScope.of(context);
    _calib = Calibration.tryParse(s.calibrationJson);
    await _loadBoard();

    _gotGaze = false;
    _gazeSub = _gaze!.watch().listen(_onGaze);
    await _gaze!.start();
    _startHeartbeat();

    _fallbackTimer?.cancel();
    _fallbackTimer = Timer(const Duration(seconds: 5), () {
      if (!_gotGaze && mounted && _gaze is! MockGaze) {
        _switchToMock();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('시선 입력이 없어 모의 시선으로 전환했습니다. 화면을 드래그해 보세요.')),
        );
      }
    });
    setState(() {});
  }

  Future<void> _loadBoard() async {
    final prefs = AppScope.of(context).prefs;
    final custom = prefs.getString('boardJson');
    Map<String, dynamic> j;
    if (custom != null && custom.isNotEmpty) {
      j = jsonDecode(custom) as Map<String, dynamic>;
    } else {
      final data = await rootBundle.loadString('assets/boards/cards_default.json');
      j = jsonDecode(data) as Map<String, dynamic>;
    }
    final board = Board.fromJson(j);
    _page = board.pages.first;
  }

  void _onGaze(GazePoint gp) {
    _gotGaze = true;
    final size = MediaQuery.of(context).size;
    final mapped = _calib?.map(gp.x, gp.y) ?? [gp.x, gp.y];
    final px = Offset(mapped[0] * size.width, mapped[1] * size.height);
    _lastNorm = mapped;

    // 좌표 미세 이동은 그리지 않음(데드존)
    if (_lastDrawnPx != null) {
      final dx = (px.dx - _lastDrawnPx!.dx).abs() / size.width;
      final dy = (px.dy - _lastDrawnPx!.dy).abs() / size.height;
      if ((dx * dx + dy * dy) < (_deadzoneNorm * _deadzoneNorm)) {
        // 그래도 dwell FSM/히트테스트는 진행
        _advanceDwell(px, mapped);
        return;
      }
    }

    // 60fps 스로틀
    final now = gp.ts;
    if (now.difference(_lastRebuild).inMicroseconds < _minFrameIntervalUs) {
      _advanceDwell(px, mapped);
      return;
    }
    _lastRebuild = now;

    _lastDrawnPx = px;
    setState(() => _cursor = px);

    _advanceDwell(px, mapped);
  }

  void _startHeartbeat() {
    _heartbeat?.cancel();
    _heartbeat = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (!mounted) return;
      if (_lastDrawnPx == null || _lastNorm == null) return;
      _advanceDwell(_lastDrawnPx!, _lastNorm!);
    });
  }

  void _advanceDwell(Offset px, List<double> norm) {
    final hit = _hitTarget(px);
    if (_lastHoverId != null && _lastHoverId != hit) {
      setState(() {});
    }
    _lastHoverId = hit;
    final s = SettingsScope.of(context);
    final state = _fsm.update(hitTargetId: hit, dwellMs: s.dwellMs);
    if (_progress != state.progress) {
      setState(() => _progress = state.progress);
    }
    _maybeSpeakReadout(s, norm, hit);
    if (state.phase == DwellPhase.triggered && state.targetId != null) {
      _onTrigger(state.targetId!);
      _fsm.reset();
      setState(() => _progress = 0.0);
    }
  }

  Future<void> _switchToMock() async {
    if (_gaze is MockGaze) return;
    await _gaze?.stop();
    await _gazeSub?.cancel();
    _gaze = MockGaze();
    await _gaze!.start();
    _gazeSub = _gaze!.watch().listen(_onGaze);
  }

  void _maybeSpeakReadout(SettingsModel s, List<double> norm, String? hitId) {
    if (!s.gazeReadout) return;
    final now = DateTime.now();
    if (now.difference(_lastReadout).inMilliseconds < 1500) return; // 1.5초 간격
    _lastReadout = now;
    final bundle = AppScope.of(context);
    if (hitId != null && _page != null) {
      final card = _page!.cards.firstWhere((c) => c.id == hitId, orElse: () => _page!.cards.first);
      bundle.tts.speak('카드 ${card.label}');
      return;
    }
    final x = (norm[0] * 100).clamp(0, 100).round();
    final y = (norm[1] * 100).clamp(0, 100).round();
    bundle.tts.speak('시선 ${x}퍼센트, ${y}퍼센트');
  }

  String? _hitTarget(Offset px) {
    for (final e in _rects.entries) {
      if (e.value.contains(px)) return e.key;
    }
    return null;
  }

  Future<void> _onTrigger(String targetId) async {
    final s = SettingsScope.of(context);
    final bundle = AppScope.of(context);
    final page = _page!;
    final card = page.cards.firstWhere((c) => c.id == targetId, orElse: () => page.cards.first);
    await bundle.logger.log('trigger', {'id': card.id});
    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate(duration: 50);
    }
    setState(() => _flash = true);
    Future.delayed(const Duration(milliseconds: 100), () => setState(() => _flash = false));

    if (card.sos) {
      if (mounted) {
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const SosDetailScreen()),
        );
      }
    } else {
      await bundle.tts.speak(card.speak);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = SettingsScope.of(context);
    final mock = s.mockGaze && (_gaze is MockGaze);

    return Scaffold(
      appBar: AppBar(
        title: Text(s.locale == 'ko' ? '에스크 아이' : 'Ask Eye'),
        actions: [
          IconButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
            icon: const Icon(Icons.settings),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CalibrationScreen()),
            ),
            icon: const Icon(Icons.center_focus_strong),
          ),
          IconButton(
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const BoardEditorScreen()),
              );
              await _loadBoard();
              if (mounted) setState(() {});
            },
            icon: const Icon(Icons.dashboard_customize),
            tooltip: '보드 편집',
          ),
        ],
      ),
      body: LayoutBuilder(builder: (context, constraints) {
        final size = constraints.biggest;
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onPanDown: mock ? (d) => (_gaze as MockGaze).updateFromPointer(d.localPosition, size) : null,
          onPanUpdate: mock ? (d) => (_gaze as MockGaze).updateFromPointer(d.localPosition, size) : null,
          child: Stack(children: [
            // 배경
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    Theme.of(context).colorScheme.surface,
                    Theme.of(context).colorScheme.surfaceVariant,
                  ], begin: Alignment.topLeft, end: Alignment.bottomRight),
                ),
              ),
            ),
            // 카드 그리드
            if (_page != null)
              Positioned.fill(
                child: CardGrid(
                  page: _page!,
                  fontScale: s.fontScale,
                  highContrast: s.highContrast,
                  onRectsReady: (r) => _rects = r,
                  onCardTap: (c) => _onTrigger(c.id),
                ),
              ),
            // 포커스 링
            if (_lastHoverId != null && _rects[_lastHoverId!] != null)
              FocusRing(rect: _rects[_lastHoverId!]!, color: Colors.amberAccent, stroke: 4),
            // 시선 커서
            GazeCursor(pos: _cursor, size: s.cursorSize, color: Color(s.cursorColor), progress: _progress, flash: _flash),
            if (mock)
              Positioned(
                top: 8,
                left: 8,
                child: DecoratedBox(
                  decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Text('Mock gaze: 화면을 탭/드래그하여 이동', style: TextStyle(color: Colors.white, fontSize: 12)),
                  ),
                ),
              ),
            // MLKit 경로일 경우, 숨김 프리뷰를 트리에 올려두어 surface를 소비
            if (_gaze is MlkitGazeRepo)
              GazeHiddenPreview(repo: _gaze as MlkitGazeRepo),
            // 폰트 스케일 컨트롤(옵션)
            Positioned(
              right: 12,
              bottom: 12,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FloatingActionButton.small(
                    heroTag: 'zoom_in',
                    onPressed: () {
                      s.fontScale = (s.fontScale + 0.1).clamp(0.8, 2.0);
                      SettingsScope.save(context);
                    },
                    child: const Icon(Icons.add),
                  ),
                  const SizedBox(height: 8),
                  FloatingActionButton.small(
                    heroTag: 'zoom_out',
                    onPressed: () {
                      s.fontScale = (s.fontScale - 0.1).clamp(0.8, 2.0);
                      SettingsScope.save(context);
                    },
                    child: const Icon(Icons.remove),
                  ),
                ],
              ),
            ),
          ]),
        );
      }),
    );
  }
}
