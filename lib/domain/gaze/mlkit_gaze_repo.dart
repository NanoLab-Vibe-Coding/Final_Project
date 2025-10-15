import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart'; // WriteBuffer
import 'package:flutter/widgets.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'gaze_repo.dart';

/// MLKit 기반 시선 추적 리포지토리
class MlkitGazeRepo implements GazeRepo {
  final _controller = StreamController<GazePoint>.broadcast();
  CameraController? _cam;
  bool _running = false;
  late FaceDetector _detector;

  MlkitGazeRepo() {
    final opts = FaceDetectorOptions(
      performanceMode: FaceDetectorMode.fast,
      enableLandmarks: true,
      enableClassification: true,
      enableTracking: true,
    );
    _detector = FaceDetector(options: opts);
  }

  @override
  Stream<GazePoint> watch() => _controller.stream;

  @override
  Future<void> start() async {
    if (_running) return;
    _running = true;

    // ✅ 카메라 목록 가져오기
    final cameras = await availableCameras();
    if (cameras.isEmpty) {
      _controller.add(GazePoint(x: 0.5, y: 0.5, valid: false));
      throw StateError('No camera available');
    }

    // ✅ 전면 카메라 우선 선택
    final camDesc = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );

    // ✅ 에뮬레이터 호환 포맷(yuv420) 사용
    _cam = CameraController(
      camDesc,
      ResolutionPreset.low,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );

    await _cam!.initialize();

    int _lastProcessTime = 0;

    // ✅ 실시간 이미지 스트림 처리
    _cam!.startImageStream((CameraImage img) async {
      if (!_running) return;

      // ✅ MLKit 프레임 처리 속도 제한 (10fps)
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now - _lastProcessTime < 100) return;
      _lastProcessTime = now;

      try {
        final input = _toInputImage(img, _cam!.description.sensorOrientation);
        final faces = await _detector.processImage(input);

        if (faces.isEmpty) {
          _controller.add(GazePoint(x: 0.5, y: 0.5, valid: false));
          return;
        }

        final face = faces.first;
        final box = face.boundingBox;
        final w = img.width.toDouble();
        final h = img.height.toDouble();

        // ✅ 중심좌표 계산
        final cx = box.center.dx.clamp(0.0, w);
        final cy = box.center.dy.clamp(0.0, h);

        // ✅ 화면 정규화 좌표 (0~1)
        final nx = 1.0 - (cx / w);
        final ny = cy / h;

        _controller.add(GazePoint(x: nx, y: ny, valid: true));
      } catch (e, st) {
        // ✅ 안전 방어 (에뮬레이터 프레임 충돌 방지)
        debugPrint('[MlkitGazeRepo] Frame skipped due to error: $e');
      }
    });
  }

  @override
  Future<void> stop() async {
    if (!_running) return;
    _running = false;

    try {
      await _cam?.stopImageStream();
    } catch (_) {}
    try {
      await _cam?.dispose();
    } catch (_) {}
    await _detector.close();
  }

  /// ✅ CameraImage → MLKit InputImage 변환
  InputImage _toInputImage(CameraImage img, int rotation) {
    final buffer = WriteBuffer();
    for (final p in img.planes) {
      buffer.putUint8List(p.bytes);
    }

    final allBytes = buffer.done().buffer.asUint8List();

    final meta = InputImageMetadata(
      size: Size(img.width.toDouble(), img.height.toDouble()),
      rotation: InputImageRotationValue.fromRawValue(rotation) ??
          InputImageRotation.rotation0deg,
      format: InputImageFormat.yuv420,
      bytesPerRow: img.planes.first.bytesPerRow,
    );

    return InputImage.fromBytes(bytes: allBytes, metadata: meta);
  }

  CameraController? get controller => _cam;
}

/// ✅ 카메라 미리보기 숨김용 위젯 (화면엔 표시 안됨)
class GazeHiddenPreview extends StatelessWidget {
  final MlkitGazeRepo repo;
  const GazeHiddenPreview({super.key, required this.repo});

  @override
  Widget build(BuildContext context) {
    final cam = repo.controller;
    if (cam == null || !cam.value.isInitialized) {
      return const SizedBox.shrink();
    }
    return Offstage(
      offstage: true,
      child: SizedBox(width: 1, height: 1, child: CameraPreview(cam)),
    );
  }
}
