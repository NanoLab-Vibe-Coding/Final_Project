// lib/data/prefs.dart
// SharedPreferences 직렬화/역직렬화

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/models/settings_model.dart';

class SettingsStore {
  static final _k = _Keys();

  static Future<SettingsModel> load(SharedPreferences prefs) async {
    return SettingsModel(
      locale: prefs.getString(_k.locale) ?? 'ko',
      dwellMs: prefs.getInt(_k.dwellMs) ?? 2000,
      highContrast: prefs.getBool(_k.highContrast) ?? false,
      fontScale: prefs.getDouble(_k.fontScale) ?? 1.0,
      darkMode: prefs.getBool(_k.darkMode) ?? false,
      cursorSize: prefs.getDouble(_k.cursorSize) ?? 32,
      cursorColor: prefs.getInt(_k.cursorColor) ?? 0xFF00BCD4,
      ttsRate: (prefs.getDouble(_k.ttsRate) ?? 0.5).clamp(0.1, 1.0),
      ttsPitch: (prefs.getDouble(_k.ttsPitch) ?? 1.0).clamp(0.5, 2.0),
      ttsVoice: prefs.getString(_k.ttsVoice),
      mockGaze: prefs.getBool(_k.mockGaze) ?? true,
      sosMode: SosModeExt.fromString(prefs.getString(_k.sosMode) ?? 'both'),
      calibrationJson: prefs.getString(_k.calibration),
      gazeReadout: prefs.getBool(_k.gazeReadout) ?? false,
    );
  }

  static Future<void> save(SharedPreferences prefs, SettingsModel s) async {
    await prefs.setString(_k.locale, s.locale);
    await prefs.setInt(_k.dwellMs, s.dwellMs);
    await prefs.setBool(_k.highContrast, s.highContrast);
    await prefs.setDouble(_k.fontScale, s.fontScale);
    await prefs.setBool(_k.darkMode, s.darkMode);
    await prefs.setDouble(_k.cursorSize, s.cursorSize);
    await prefs.setInt(_k.cursorColor, s.cursorColor);
    await prefs.setDouble(_k.ttsRate, s.ttsRate);
    await prefs.setDouble(_k.ttsPitch, s.ttsPitch);
    if (s.ttsVoice != null) {
      await prefs.setString(_k.ttsVoice, s.ttsVoice!);
    }
    await prefs.setBool(_k.mockGaze, s.mockGaze);
    await prefs.setString(_k.sosMode, s.sosMode.name);
    if (s.calibrationJson != null) {
      await prefs.setString(_k.calibration, s.calibrationJson!);
    }
    await prefs.setBool(_k.gazeReadout, s.gazeReadout);
  }
}

class _Keys {
  final locale = 'locale';
  final dwellMs = 'dwellMs';
  final highContrast = 'highContrast';
  final fontScale = 'fontScale';
  final darkMode = 'darkMode';
  final cursorSize = 'cursorSize';
  final cursorColor = 'cursorColor';
  final ttsRate = 'ttsRate';
  final ttsPitch = 'ttsPitch';
  final ttsVoice = 'ttsVoice';
  final mockGaze = 'mockGaze';
  final sosMode = 'sosMode';
  final calibration = 'calibration';
  final gazeReadout = 'gazeReadout';
  final boardJson = 'boardJson';
}
