import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'ui/screens/camera_screen.dart'; // ✅ CameraScreen import

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _ensureCameraPermission();
  runApp(const MyApp());
}

Future<void> _ensureCameraPermission() async {
  var status = await Permission.camera.status;

  if (status.isDenied) {
    status = await Permission.camera.request();
  }

  if (status.isPermanentlyDenied) {
    await openAppSettings();
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ask Eye',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ),
      home: CameraScreen(), // ✅ const 제거 완료
    );
  }
}
