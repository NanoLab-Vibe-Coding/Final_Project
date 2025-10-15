// lib/domain/gaze/mock_gaze.dart
// 제스처 입력을 시선 포인트로 변환하는 모의 구현

import 'dart:async';
import 'package:flutter/material.dart';

import 'gaze_repo.dart';

class MockGaze implements GazeRepo {
  final _controller = StreamController<GazePoint>.broadcast();
  bool _running = false;

  @override
  Stream<GazePoint> watch() => _controller.stream;

  @override
  Future<void> start() async {
    _running = true;
  }

  @override
  Future<void> stop() async {
    _running = false;
  }

  // UI에서 GestureDetector로 전달: 화면 픽셀 좌표 -> 0..1 정규화
  void updateFromPointer(Offset pos, Size size) {
    if (!_running) return;
    final nx = (pos.dx / size.width).clamp(0.0, 1.0);
    final ny = (pos.dy / size.height).clamp(0.0, 1.0);
    _controller.add(GazePoint(x: nx, y: ny, valid: true, ts: DateTime.now()));
  }
}

