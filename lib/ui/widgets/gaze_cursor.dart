// lib/ui/widgets/gaze_cursor.dart
// 시선 커서 + 진행 링

import 'package:flutter/material.dart';

class GazeCursor extends StatelessWidget {
  final Offset pos; // 픽셀 좌표
  final double size;
  final Color color;
  final double progress; // 0..1 dwell 진행률
  final bool flash; // 피드백 점멸
  const GazeCursor({super.key, required this.pos, required this.size, required this.color, required this.progress, this.flash = false});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: pos.dx - size / 2,
      top: pos.dy - size / 2,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 120),
        opacity: flash ? 0.2 : 1.0,
        child: CustomPaint(
          size: Size.square(size),
          painter: _CursorPainter(color: color, progress: progress),
        ),
      ),
    );
  }
}

class _CursorPainter extends CustomPainter {
  final Color color;
  final double progress;
  _CursorPainter({required this.color, required this.progress});
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2;
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..color = color;
    final fill = Paint()
      ..style = PaintingStyle.fill
      ..color = color.withOpacity(0.15);
    canvas.drawCircle(center, radius, fill);
    final sweep = 2 * 3.1415926535 * progress;
    canvas.drawArc(Offset.zero & size, -3.1415926535 / 2, sweep, false, ring);
    // 중앙 흰 점(시선 포인트 강조)
    final white = Paint()..color = Colors.white;
    canvas.drawCircle(center, size.width * 0.06, white);
  }

  @override
  bool shouldRepaint(covariant _CursorPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.progress != progress;
}
