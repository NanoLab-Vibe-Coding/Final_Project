// lib/ui/a11y/high_contrast.dart
// 위젯 단위 고대비 보정 도우미

import 'package:flutter/material.dart';

class HighContrast extends InheritedWidget {
  final bool enabled;
  const HighContrast({super.key, required this.enabled, required super.child});

  static bool of(BuildContext context) {
    final w = context.dependOnInheritedWidgetOfExactType<HighContrast>();
    return w?.enabled ?? false;
  }

  @override
  bool updateShouldNotify(covariant HighContrast oldWidget) => enabled != oldWidget.enabled;
}

