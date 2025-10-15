// lib/ui/widgets/web_camera_view.dart
// 플랫폼별 구현을 조건부로 내보냄

export 'web_camera_view_stub.dart' if (dart.library.html) 'web_camera_view_web.dart';

