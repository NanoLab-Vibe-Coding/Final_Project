// lib/ui/widgets/android_camerax_preview.dart
// Android 네이티브 CameraX PreviewView를 PlatformView로 표시

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class AndroidCameraxPreview extends StatelessWidget {
  const AndroidCameraxPreview({super.key});
  @override
  Widget build(BuildContext context) {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return const SizedBox.shrink();
    }
    return const AndroidView(viewType: 'camerax_preview');
  }
}

