// lib/domain/sos/sos_service.dart
// SOS 트리거: 진동 패턴, 화면 점멸 유발(호출부), 전화/문자 실행

import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vibration/vibration.dart';

import '../../core/logger.dart';
import '../models/settings_model.dart';
import '../tts/tts_service.dart';

class SosService {
  final AppLogger logger;
  final TtsService tts;
  SosService({required this.logger, required this.tts});

  Future<void> trigger({required SosMode mode, String? callNumber, String? smsBody}) async {
    await logger.log('sos', {'mode': mode.name, 'call': callNumber, 'sms': smsBody});
    await _vibrateStrong();
    await tts.speak('도움을 요청합니다');
    if (mode == SosMode.call || mode == SosMode.both) {
      await _tryCall(callNumber);
    }
    if (mode == SosMode.sms || mode == SosMode.both) {
      await _trySms(smsBody);
    }
  }

  Future<void> _vibrateStrong() async {
    if (await Vibration.hasVibrator() ?? false) {
      // 강한 패턴 3회
      await Vibration.vibrate(pattern: [0, 400, 200, 400, 200, 600]);
    }
  }

  Future<void> _tryCall(String? number) async {
    if (number == null || number.isEmpty) return;
    final p = await Permission.phone.request();
    if (!p.isGranted) return;
    final uri = Uri(scheme: 'tel', path: number);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _trySms(String? body) async {
    final uri = Uri(scheme: 'sms', queryParameters: {'body': body ?? '긴급 도움이 필요합니다'});
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }
}

