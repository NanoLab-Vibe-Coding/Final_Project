// lib/ui/screens/sos_detail_screen.dart
// SOS 상세 다이얼: 112/119 등 번호를 큰 버튼으로 제공, 응시로 선택 시 전화 연결

import 'dart:async';

import 'package:flutter/material.dart';

import '../../app.dart';
import '../../domain/gaze/dwell_fsm.dart';
import '../../domain/gaze/gaze_repo.dart';
import '../../domain/gaze/mock_gaze.dart';
import '../../domain/models/settings_model.dart';
import '../../domain/sos/sos_service.dart';

class SosDetailScreen extends StatefulWidget {
  const SosDetailScreen({super.key});
  @override
  State<SosDetailScreen> createState() => _SosDetailScreenState();
}

class _SosDetailScreenState extends State<SosDetailScreen> {
  final Map<String, GlobalKey> _keys = {
    '112': GlobalKey(),
    '119': GlobalKey(),
    'custom': GlobalKey(),
  };
  Map<String, Rect> _rects = {};
  DwellFsm _fsm = DwellFsm();
  GazeRepo? _gaze;
  StreamSubscription<GazePoint>? _sub;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _gaze ??= AppScope.of(context).gaze;
    _sub ??= _gaze!.watch().listen(_onGaze);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _collectRects() {
    final Map<String, Rect> rects = {};
    _keys.forEach((id, key) {
      final ctx = key.currentContext;
      if (ctx != null) {
        final box = ctx.findRenderObject() as RenderBox?;
        if (box != null && box.hasSize) {
          rects[id] = box.localToGlobal(Offset.zero) & box.size;
        }
      }
    });
    _rects = rects;
  }

  void _onGaze(GazePoint gp) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _collectRects());
    final size = MediaQuery.of(context).size;
    final px = Offset(gp.x * size.width, gp.y * size.height);
    String? hit;
    for (final e in _rects.entries) {
      if (e.value.contains(px)) { hit = e.key; break; }
    }
    final s = SettingsScope.of(context);
    final st = _fsm.update(hitTargetId: hit, dwellMs: s.dwellMs);
    if (st.phase == DwellPhase.triggered && st.targetId != null) {
      _trigger(st.targetId!);
      _fsm.reset();
    }
  }

  Future<void> _trigger(String id) async {
    final bundle = AppScope.of(context);
    switch (id) {
      case '112':
        await bundle.sos.trigger(mode: SosMode.call, callNumber: '112');
        break;
      case '119':
        await bundle.sos.trigger(mode: SosMode.call, callNumber: '119');
        break;
      case 'custom':
        final number = await _askNumber();
        if (number != null && number.isNotEmpty) {
          await bundle.sos.trigger(mode: SosMode.call, callNumber: number);
        }
        break;
    }
  }

  Future<String?> _askNumber() async {
    final c = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('전화번호 입력'),
        content: TextField(controller: c, keyboardType: TextInputType.phone, decoration: const InputDecoration(hintText: '예: 01012345678')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
          ElevatedButton(onPressed: () => Navigator.pop(context, c.text.trim()), child: const Text('확인')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = SettingsScope.of(context);
    final mock = s.mockGaze && (_gaze is MockGaze);
    return Scaffold(
      appBar: AppBar(title: const Text('긴급 도움')),
      body: LayoutBuilder(builder: (context, constraints) {
        final size = constraints.biggest;
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onPanDown: mock ? (d) => (_gaze as MockGaze).updateFromPointer(d.localPosition, size) : null,
          onPanUpdate: mock ? (d) => (_gaze as MockGaze).updateFromPointer(d.localPosition, size) : null,
          onTapDown: mock ? (d) => (_gaze as MockGaze).updateFromPointer(d.localPosition, size) : null,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _bigButton('112', Icons.local_police, key: _keys['112']),
                  const SizedBox(height: 16),
                  _bigButton('119', Icons.local_fire_department, key: _keys['119']),
                  const SizedBox(height: 16),
                  _bigButton('사용자 지정', Icons.phone, id: 'custom', key: _keys['custom']),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _bigButton(String label, IconData icon, {String? id, Key? key}) {
    final theId = id ?? label;
    return SizedBox(
      width: double.infinity,
      height: 84,
      child: ElevatedButton(
        key: key,
        onPressed: () => _trigger(theId),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [Icon(icon, size: 28), const SizedBox(width: 12), Text(label, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold))],
        ),
      ),
    );
  }
}
