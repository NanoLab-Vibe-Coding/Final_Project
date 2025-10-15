// lib/domain/tts/tts_service.dart
// flutter_tts 래퍼. ko-KR 기본. 속도/피치 조정.

import 'package:flutter_tts/flutter_tts.dart';
import '../../core/logger.dart';

class TtsService {
  final FlutterTts _tts = FlutterTts();
  final AppLogger logger;
  TtsService({required this.logger});

  Future<void> init({required String language, required double rate, required double pitch, String? voice}) async {
    try {
      await _tts.setLanguage(language == 'ko' ? 'ko-KR' : 'en-US');
      await _tts.setSpeechRate(rate);
      await _tts.setPitch(pitch);
      if (voice != null) {
        try {
          await _tts.setVoice({'name': voice});
        } catch (_) {}
      }
    } catch (_) {
      // 웹 등 미지원 플랫폼은 조용히 통과
    }
  }

  Future<void> speak(String text) async {
    await logger.log('tts', {'text': text});
    try {
      await _tts.stop();
      await _tts.speak(text);
    } catch (_) {
      // 미지원 플랫폼: 무시
    }
  }

  Future<void> dispose() async {
    await _tts.stop();
  }
}
