// lib/domain/gaze/mlkit_adapter_mobile.dart
// Android/iOS용 ML Kit 얼굴 검출을 이용한 간단 시선 포인트 추정

import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show WriteBuffer;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

typedef GazeCallback = void Function(double x, double y);

class MlkitAdapter {
  FaceDetector? _detector;
  bool _processing = false;
  int _frameCount = 0;
  List<double>? _last;
  StreamSubscription<CameraImage>? _sub;

  Future<bool> start(CameraController cam, GazeCallback onPoint) async {
    _detector?.close();
    _detector = FaceDetector(
      options: FaceDetectorOptions(
        enableLandmarks: true,
        performanceMode: FaceDetectorMode.accurate,
      ),
    );
    await cam.startImageStream((image) => _process(cam, image, onPoint));
    return true;
  }

  Future<void> stop(CameraController cam) async {
    try {
      await cam.stopImageStream();
    } catch (_) {}
    await _detector?.close();
    _detector = null;
  }

  InputImageRotation _rotationIntToImageRotation(int rotation) {
    switch (rotation) {
      case 0:
        return InputImageRotation.rotation0deg;
      case 90:
        return InputImageRotation.rotation90deg;
      case 180:
        return InputImageRotation.rotation180deg;
      case 270:
        return InputImageRotation.rotation270deg;
      default:
        return InputImageRotation.rotation0deg;
    }
  }

  Future<void> _process(CameraController cam, CameraImage image, GazeCallback onPoint) async {
    if (_processing || _detector == null) return;
    _processing = true;
    try {
      _frameCount++;
      if (_frameCount % 2 == 1) return; // 샘플링
      final WriteBuffer allBytes = WriteBuffer();
      for (final Plane plane in image.planes) {
        allBytes.putUint8List(plane.bytes);
      }
      final bytes = allBytes.done().buffer.asUint8List();
      final Size size = Size(image.width.toDouble(), image.height.toDouble());
      final rotation = _rotationIntToImageRotation(cam.description.sensorOrientation);
      final inputImage = InputImage.fromBytes(
        bytes: bytes,
        metadata: InputImageMetadata(
          size: size,
          rotation: rotation,
          format: InputImageFormat.yuv420,
          bytesPerRow: image.planes.first.bytesPerRow,
        ),
      );
      final faces = await _detector!.processImage(inputImage);
      if (faces.isNotEmpty) {
        final f = faces.first;
        final le = f.landmarks[FaceLandmarkType.leftEye]?.position;
        final re = f.landmarks[FaceLandmarkType.rightEye]?.position;
        double cx, cy;
        if (le != null && re != null) {
          cx = ((le.x + re.x) / 2) / size.width;
          cy = ((le.y + re.y) / 2) / size.height;
        } else {
          // 랜드마크가 없으면 얼굴 중심으로 대체
          final bb = f.boundingBox;
          cx = (bb.center.dx / size.width).clamp(0.0, 1.0);
          cy = (bb.center.dy / size.height).clamp(0.0, 1.0);
        }
        final alpha = 0.6;
        if (_last == null) {
          _last = [cx, cy];
        } else {
          _last = [
            _last![0] * (1 - alpha) + cx * alpha,
            _last![1] * (1 - alpha) + cy * alpha,
          ];
        }
        onPoint(_last![0], _last![1]);
      }
    } catch (_) {
      // 무시
    } finally {
      _processing = false;
    }
  }
}
