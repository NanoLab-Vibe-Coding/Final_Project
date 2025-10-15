// 3x3 타겟 보정: initState에서 AppScope 접근하던 문제를 didChangeDependencies로 이동

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';

import '../../app.dart';
import '../../domain/gaze/gaze_repo.dart';
import '../../domain/gaze/calibration.dart';

class CalibrationScreen extends StatefulWidget {
  const CalibrationScreen({super.key});
  @override
  State<CalibrationScreen> createState() => _CalibrationScreenState();
}

class _CalibrationScreenState extends State<CalibrationScreen> {
  int _idx = 0; // 0..8
  final List<List<double>> _raw = [];
  final List<List<double>> _scr = [];
  StreamSubscription<GazePoint>? _sub;
  final List<List<double>> _samples = [];
  bool _running = false;
  GazeRepo? _gaze;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      _gaze = AppScope.of(context).gaze;
      // 프레임 안정화 후 시작
      WidgetsBinding.instance.addPostFrameCallback((_) => _startPoint());
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  List<Offset> _targets(Size size) {
    final cols = 3, rows = 3;
    final List<Offset> ts = [];
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final x = (c + 1) / (cols + 1);
        final y = (r + 1) / (rows + 1);
        ts.add(Offset(size.width * x, size.height * y));
      }
    }
    return ts;
  }

  Future<void> _startPoint() async {
    _samples.clear();
    _running = true;
    await _gaze?.start();
    _sub?.cancel();
    _sub = _gaze?.watch().listen((p) {
      if (!_running) return;
      if (p.valid) _samples.add([p.x, p.y]);
    });
    await Future.delayed(const Duration(milliseconds: 1000));
    _running = false;
    final avg = _samples.isEmpty
        ? [0.5, 0.5]
        : [
            _samples.map((e) => e[0]).reduce((a, b) => a + b) / _samples.length,
            _samples.map((e) => e[1]).reduce((a, b) => a + b) / _samples.length,
          ];
    _raw.add(avg);
    if (mounted) setState(() {});
  }

  Future<void> _next(Size size) async {
    _idx++;
    if (_idx >= 9) {
      final t = _targets(size);
      for (final off in t) {
        _scr.add([off.dx / size.width, off.dy / size.height]);
      }
      final calib = Calibration.solve(_raw, _scr);
      final s = SettingsScope.of(context);
      s.calibrationJson = jsonEncode(calib.toJson());
      await SettingsScope.save(context);
      if (mounted) Navigator.pop(context);
      return;
    }
    await _startPoint();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final size = constraints.biggest;
      final ts = _targets(size);
      final target = ts[_idx];
      return Scaffold(
        appBar: AppBar(title: Text(SettingsScope.of(context).locale == 'ko' ? '보정' : 'Calibration')),
        body: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _next(size),
          child: Stack(children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _TargetsPainter(points: ts, highlight: _idx),
              ),
            ),
            Positioned(left: target.dx - 12, top: target.dy - 12, child: _Dot(color: Colors.red, size: 24)),
            Positioned(
              bottom: 32,
              left: 0,
              right: 0,
              child: Center(
                child: Text('${_idx + 1} / 9', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              ),
            ),
          ]),
        ),
      );
    });
  }
}

class _TargetsPainter extends CustomPainter {
  final List<Offset> points;
  final int highlight;
  _TargetsPainter({required this.points, required this.highlight});
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..style = PaintingStyle.fill;
    for (var i = 0; i < points.length; i++) {
      p.color = i == highlight ? Colors.red : Colors.grey;
      canvas.drawCircle(points[i], i == highlight ? 10 : 6, p);
    }
  }

  @override
  bool shouldRepaint(covariant _TargetsPainter oldDelegate) => oldDelegate.highlight != highlight;
}

class _Dot extends StatelessWidget {
  final Color color;
  final double size;
  const _Dot({required this.color, required this.size});
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
}
