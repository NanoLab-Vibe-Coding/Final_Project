// lib/domain/models/settings_model.dart

enum SosMode { call, sms, both }

extension SosModeExt on SosMode {
  static SosMode fromString(String v) {
    switch (v) {
      case 'call':
        return SosMode.call;
      case 'sms':
        return SosMode.sms;
      default:
        return SosMode.both;
    }
  }
}

class SettingsModel {
  String locale;
  int dwellMs;
  bool highContrast;
  double fontScale;
  bool darkMode;
  double cursorSize;
  int cursorColor;
  double ttsRate;
  double ttsPitch;
  String? ttsVoice;
  bool mockGaze;
  SosMode sosMode;
  String? calibrationJson; // Calibration 직렬화 저장
  bool gazeReadout; // 실시간 시선 읽어주기

  SettingsModel({
    required this.locale,
    required this.dwellMs,
    required this.highContrast,
    required this.fontScale,
    required this.darkMode,
    required this.cursorSize,
    required this.cursorColor,
    required this.ttsRate,
    required this.ttsPitch,
    required this.ttsVoice,
    required this.mockGaze,
    required this.sosMode,
    required this.calibrationJson,
    this.gazeReadout = false,
  });
}
