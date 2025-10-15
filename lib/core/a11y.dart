// lib/core/a11y.dart
// 접근성 유틸: 최소 터치 영역, 포커스 링, 색상만 의존 방지 안내.

import 'package:flutter/material.dart';

const double kMinTouchTarget = 64.0; // 64dp 최소 터치 목표

class FocusRing extends StatelessWidget {
  final Rect rect;
  final Color color;
  final double stroke;
  const FocusRing({super.key, required this.rect, required this.color, this.stroke = 3});
  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: rect.left,
      top: rect.top,
      child: IgnorePointer(
        child: CustomPaint(
          size: Size(rect.width, rect.height),
          painter: _RingPainter(color: color, stroke: stroke),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final Color color;
  final double stroke;
  _RingPainter({required this.color, required this.stroke});
  @override
  void paint(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(12));
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = color;
    canvas.drawRRect(r, p);
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.stroke != stroke;
}

