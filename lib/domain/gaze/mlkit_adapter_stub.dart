// lib/domain/gaze/mlkit_adapter_stub.dart
// 웹 등 미지원 플랫폼 스텁: 아무 동작도 하지 않음

import 'package:camera/camera.dart';

typedef GazeCallback = void Function(double x, double y);

class MlkitAdapter {
  Future<bool> start(CameraController cam, GazeCallback onPoint) async => false;
  Future<void> stop(CameraController cam) async {}
}

