// lib/platform/android_channel.dart
import 'dart:async';
import 'package:flutter/services.dart';
import '../../domain/gaze/gaze_repo.dart';

const _method = MethodChannel('gaze/android');
const _event = EventChannel('gaze/android/stream');

class AndroidGazeRepo implements GazeRepo {
  StreamController<GazePoint>? _ctrl;
  StreamSubscription? _sub;
  bool _running = false;

  @override
  Future<void> start() async {
    if (_running) return;
    _running = true;

    _ctrl = StreamController<GazePoint>.broadcast();

    // 이벤트 수신
    _sub = _event.receiveBroadcastStream().listen((e) {
      if (e is Map) {
        final x = (e['x'] as num?)?.toDouble() ?? 0.5;
        final y = (e['y'] as num?)?.toDouble() ?? 0.5;
        final v = (e['valid'] as bool?) ?? false;
        _ctrl?.add(GazePoint(x: x, y: y, valid: v));
      }
    }, onError: (err) {
      _ctrl?.add(GazePoint(x: 0.5, y: 0.5, valid: false));
    });

    // 네이티브 카메라 시작
    await _method.invokeMethod('start', {'headless': true});
  }

  @override
  Future<void> stop() async {
    if (!_running) return;
    _running = false;
    try {
      await _method.invokeMethod('stop');
    } catch (_) {}
    await _sub?.cancel();
    await _ctrl?.close();
    _ctrl = null;
    _sub = null;
  }

  @override
  Stream<GazePoint> watch() {
    _ctrl ??= StreamController<GazePoint>.broadcast();
    return _ctrl!.stream;
  }
}
