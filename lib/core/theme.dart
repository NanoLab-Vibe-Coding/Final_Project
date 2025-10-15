// lib/core/theme.dart
// Material 3 테마, 고대비/다크모드 지원. 텍스트 대비 4.5:1 이상 목표.

import 'package:flutter/material.dart';

ThemeData buildAppTheme({required bool highContrast, required Brightness brightness}) {
  final base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    // 녹색 톤 제거: 중립적인 블루그레이 기반으로 통일
    colorSchemeSeed: Colors.blueGrey,
  );

  final textTheme = base.textTheme.apply(
    bodyColor: _onSurfaceFor(brightness, highContrast),
    displayColor: _onSurfaceFor(brightness, highContrast),
  );

  final elevated = ElevatedButtonThemeData(
    style: ButtonStyle(
      minimumSize: const MaterialStatePropertyAll(Size(64, 64)),
      textStyle: MaterialStatePropertyAll(textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
      backgroundColor: MaterialStateProperty.resolveWith((states) {
        if (states.contains(MaterialState.disabled)) {
          return base.colorScheme.surfaceVariant;
        }
        return highContrast ? Colors.black : base.colorScheme.primary;
      }),
      foregroundColor: MaterialStatePropertyAll(highContrast ? Colors.yellow : base.colorScheme.onPrimary),
    ),
  );

  return base.copyWith(
    textTheme: textTheme,
    elevatedButtonTheme: elevated,
    visualDensity: VisualDensity.standard,
    iconTheme: base.iconTheme.copyWith(color: _onSurfaceFor(brightness, highContrast)),
    appBarTheme: base.appBarTheme.copyWith(
      backgroundColor: highContrast ? Colors.black : null,
      foregroundColor: highContrast ? Colors.yellow : null,
      centerTitle: true,
    ),
  );
}

Color _onSurfaceFor(Brightness brightness, bool highContrast) {
  if (highContrast) return brightness == Brightness.dark ? Colors.yellow : Colors.black;
  return brightness == Brightness.dark ? Colors.white : Colors.black87;
}
