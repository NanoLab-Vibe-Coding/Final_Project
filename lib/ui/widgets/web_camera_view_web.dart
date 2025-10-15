// lib/ui/widgets/web_camera_view_web.dart
// Flutter Web용 카메라 프리뷰 구현(HTML Video + getUserMedia)

// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';

class WebCameraView extends StatefulWidget {
  const WebCameraView({super.key});
  @override
  State<WebCameraView> createState() => _WebCameraViewState();
}

class _WebCameraViewState extends State<WebCameraView> {
  late final String _viewType;
  html.VideoElement? _video;

  @override
  void initState() {
    super.initState();
    _viewType = 'web-camera-view-${DateTime.now().microsecondsSinceEpoch}';
    registerViewFactory(_viewType, (int viewId) {
      _video = html.VideoElement()
        ..style.width = '100%'
        ..style.height = '100%'
        ..autoplay = true
        ..muted = true
        ..setAttribute('playsinline', 'true');
      html.window.navigator.mediaDevices
          ?.getUserMedia({'video': {'facingMode': 'user'}})
          .then((stream) => _video!.srcObject = stream)
          .catchError((_) {});
      return _video!;
    });
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: _viewType);
  }

  @override
  void dispose() {
    final media = _video?.srcObject as html.MediaStream?;
    media?.getTracks().forEach((t) => t.stop());
    _video?.srcObject = null;
    super.dispose();
  }
}
