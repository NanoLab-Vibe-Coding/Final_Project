// lib/ui/a11y/font_scaler.dart
// 텍스트 스케일 팩터 적용

import 'package:flutter/material.dart';

class FontScaler extends StatelessWidget {
  final double scale;
  final Widget child;
  const FontScaler({super.key, required this.scale, required this.child});

  @override
  Widget build(BuildContext context) {
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
      child: child,
    );
  }
}

