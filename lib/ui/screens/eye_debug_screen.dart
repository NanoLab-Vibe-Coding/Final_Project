// lib/ui/screens/eye_debug_screen.dart
// 온디바이스 시선 입력 디버그 화면.
// 변경점
// 1) Android Camerax PlatformView(미등록 시 crash) 의존 제거 → 항상 안전한 배경으로 표시
// 2) EPS(초당 이벤트) 3초 연속 0이면 자동 Mock 폴백
// 3) 레포 생성은 항상 selectGazeRepo(onDevicePreferred)로 일관 처리

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../app.dart';
import '../../domain/gaze/gaze_repo.dart';   // selectGazeRepo, GazePoint
import '../../domain/gaze/mock_gaze.dart';
import '../../domain/gaze/calibration.dart';

class EyeDebugScreen extends StatefulWidget {
  const EyeDebugScreen({super.key});
  @override
  State<EyeDebugScreen> createState() => _EyeDebugScreenState();
}

class _EyeDebugScreenState extends State<EyeDebugScreen> {
  GazeRepo? _gaze;
  StreamSubscription<GazePoint>? _sub;

  Offset _px = Offset.zero;
  final List<Offset> _trail = [];

  int _events = 0;  // 초당 이벤트 카운터 내부 누적
  int _eps = 0;     // 매초 갱신해서 화면에 표시
  Timer? _epsTimer;
  Timer? _fallbackTimer; // EPS=0 자동 폴백 감시 타이머

  Calibration? _calib;

  @override
  void initState() {
    super.initState();
    _epsTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        _eps = _events;
        _events = 0;
      });
    });
    _fallbackTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      // 3초 동안 EPS가 0이면 Mock으로 전환
      if (!mounted) return;
      if (_eps == 0 && _gaze is! MockGaze) {
        await _recreateRepo(wantOnDevice: false);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('시선 입력이 없어 Mock으로 전환했습니다. 화면을 드래그해 보세요.')),
        );
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final s = SettingsScope.of(context);
    _calib = Calibration.tryParse(s.calibrationJson);

    final wantOnDevice =
        (!kIsWeb && defaultTargetPlatform == TargetPlatform.android && !s.mockGaze);

    if (_gaze == null) {
      _gaze = selectGazeRepo(onDevicePreferred: wantOnDevice);
      _sub = _gaze!.watch().listen(_onGaze);
      _gaze!.start(); // 먼저 구독 후 시작
    } else {
      // 설정이 바뀌었으면 재구성
      final usingMock = _gaze is MockGaze;
      if (wantOnDevice && usingMock) {
        _recreateRepo(wantOnDevice: true);
      } else if (!wantOnDevice && !usingMock) {
        _recreateRepo(wantOnDevice: false);
      }
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _epsTimer?.cancel();
    _fallbackTimer?.cancel();
    try {
      _gaze?.stop();
    } catch (_) {}
    super.dispose();
  }

  Future<void> _recreateRepo({required bool wantOnDevice}) async {
    await _sub?.cancel();
    try { await _gaze?.stop(); } catch (_) {}
    _gaze = selectGazeRepo(onDevicePreferred: wantOnDevice);
    _sub = _gaze!.watch().listen(_onGaze);
    await _gaze!.start();
    if (mounted) setState(() {});
  }

  void _onGaze(GazePoint gp) {
    _events++;
    final size = MediaQuery.of(context).size;
    final norm = _calib?.map(gp.x, gp.y) ?? [gp.x, gp.y];
    final p = Offset(norm[0] * size.width, norm[1] * size.height);
    setState(() {
      _px = p;
      _trail.add(p);
      if (_trail.length > 60) _trail.removeAt(0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = SettingsScope.of(context);
    final usingMock = (_gaze is MockGaze) || s.mockGaze;

    return Scaffold(
      appBar: AppBar(
        title: const Text('시선 디버그 보기'),
        actions: [
          IconButton(
            onPressed: () => Navigator.pushReplacementNamed(context, '/camera'),
            icon: const Icon(Icons.home),
          ),
          IconButton(
            tooltip: '레포 재시작',
            onPressed: () async =>
                _recreateRepo(wantOnDevice: usingMock /* 토글 */ ? false : true),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: LayoutBuilder(builder: (context, constraints) {
        final size = constraints.biggest;
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onPanDown: usingMock
              ? (d) => (_gaze as MockGaze).updateFromPointer(d.localPosition, size)
              : null,
          onPanUpdate: usingMock
              ? (d) => (_gaze as MockGaze).updateFromPointer(d.localPosition, size)
              : null,
          onTapDown: usingMock
              ? (d) => (_gaze as MockGaze).updateFromPointer(d.localPosition, size)
              : null,
          child: Stack(children: [
            // ✅ 프리뷰 의존 제거: 항상 안전한 배경
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                ),
              ),
            ),
            // 상태 배지
            Positioned(
              left: 8,
              top: 8,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Text(
                    usingMock ? '상태: Mock  | EPS: $_eps' : '상태: On-device  | EPS: $_eps',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ),
            // 트레일
            Positioned.fill(child: CustomPaint(painter: _TrailPainter(_trail))),
            // 십자선 커서
            Positioned(
              left: _px.dx - 1,
              top: _px.dy - 1,
              child: const IgnorePointer(child: _Crosshair()),
            ),
            // 좌표 텍스트
            Positioned(
              bottom: 16,
              left: 16,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Text(
                    'x: ${(_px.dx / size.width * 100).clamp(0, 100).toStringAsFixed(1)}%  '
                    'y: ${(_px.dy / size.height * 100).clamp(0, 100).toStringAsFixed(1)}% ',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ),
          ]),
        );
      }),
    );
  }
}

class _Crosshair extends StatelessWidget {
  const _Crosshair();
  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: const Size(2, 2), painter: _CrossPainter());
  }
}

class _CrossPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = Colors.yellow..strokeWidth = 2;
    canvas.drawCircle(Offset.zero, 10, p..style = PaintingStyle.stroke);
    canvas.drawLine(const Offset(-12, 0), const Offset(12, 0), p);
    canvas.drawLine(const Offset(0, -12), const Offset(0, 12), p);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _TrailPainter extends CustomPainter {
  final List<Offset> pts;
  const _TrailPainter(this.pts);
  @override
  void paint(Canvas canvas, Size size) {
    if (pts.length < 2) return;
    final p = Paint()
      ..color = Colors.lightBlueAccent.withOpacity(0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (int i = 1; i < pts.length; i++) {
      path.lineTo(pts[i].dx, pts[i].dy);
    }
    canvas.drawPath(path, p);
  }
  @override
  bool shouldRepaint(covariant _TrailPainter oldDelegate) =>
      !listEquals(oldDelegate.pts, pts);
}
