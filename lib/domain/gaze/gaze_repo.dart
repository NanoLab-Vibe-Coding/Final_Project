// lib/domain/gaze/gaze_repo.dart
import 'dart:async';
import 'dart:math' as math;

import 'mlkit_gaze_repo.dart';
import 'mock_gaze.dart';
import '../../platform/android_channel.dart'; // Android 네이티브 브리지

/// 시선 포인트 데이터 클래스
class GazePoint {
  final double x;
  final double y;
  final bool valid;
  final DateTime ts;

  GazePoint({
    required this.x,
    required this.y,
    this.valid = true,
    DateTime? ts,
  }) : ts = ts ?? DateTime.now();

  @override
  String toString() =>
      'GazePoint(x: ${x.toStringAsFixed(3)}, y: ${y.toStringAsFixed(3)}, valid: $valid, ts: $ts)';
}

/// Gaze 데이터 공급 추상 클래스
abstract class GazeRepo {
  Future<void> start();
  Future<void> stop();
  Stream<GazePoint> watch();
}

/// 부드럽게 스무딩 처리하는 시선 데이터 래퍼
class GazeSmoothingRepo implements GazeRepo {
  final GazeRepo inner;
  final double alpha; // 스무딩 계수
  StreamController<GazePoint>? _ctrl;
  StreamSubscription<GazePoint>? _sub;
  GazePoint? _last;

  GazeSmoothingRepo(this.inner, {this.alpha = 0.35});

  @override
  Future<void> start() async {
    _ctrl = StreamController<GazePoint>.broadcast();

    // 내부 스트림 구독
    _sub = inner.watch().listen((p) {
      if (_last == null) {
        _last = p;
      } else {
        // EMA(Exponential Moving Average) 스무딩
        final lx = _last!.x + alpha * (p.x - _last!.x);
        final ly = _last!.y + alpha * (p.y - _last!.y);
        _last = GazePoint(x: lx, y: ly, valid: p.valid);
      }
      _ctrl?.add(_last!);
    }, onError: (e, st) {
      print('[GazeSmoothingRepo] inner stream error: $e');
    });

    try {
      await inner.start();
    } catch (e) {
      print('[GazeSmoothingRepo] inner.start() failed: $e');
    }
  }

  @override
  Future<void> stop() async {
    try {
      await inner.stop();
    } catch (e) {
      print('[GazeSmoothingRepo] inner.stop() failed: $e');
    }

    await _sub?.cancel();
    await _ctrl?.close();
    _sub = null;
    _ctrl = null;
    _last = null;
  }

  @override
  Stream<GazePoint> watch() {
    _ctrl ??= StreamController<GazePoint>.broadcast();
    return _ctrl!.stream;
  }
}

/// ✅ 자동 선택: MLKit → Android Channel → Mock 순서로 시선추적 소스 선택
GazeRepo selectGazeRepo({required bool onDevicePreferred}) {
  if (onDevicePreferred) {
    // 1) Android 네이티브 채널 우선 (MediaImage 경로로 포맷 문제 최소화)
    try {
      print('[GazeRepo] Trying Android native channel...');
      return GazeSmoothingRepo(AndroidGazeRepo(), alpha: 0.35);
    } catch (e) {
      print('[GazeRepo] Android Channel init failed: $e');
    }

    // 2) Dart MLKit 경로 (카메라 이미지 바이트 변환)
    try {
      print('[GazeRepo] Trying MLKit Gaze detection...');
      return GazeSmoothingRepo(MlkitGazeRepo(), alpha: 0.35);
    } catch (e) {
      print('[GazeRepo] MLKit init failed: $e');
    }
  }

  // 3) 마지막 fallback: Mock
  print('[GazeRepo] Falling back to Mock Gaze stream.');
  return MockGaze();
}
