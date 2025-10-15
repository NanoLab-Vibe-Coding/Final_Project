// lib/app.dart
// 앱 초기화, 서비스 구성, 라우팅 및 테마 적용
//
// 변경 사항:
// - 첫 프레임 이후에 _bootstrap()을 실행해 초기 렌더의 큰 렉을 줄임.
// - _init 할당 전에는 초경량 로딩 화면을 보여줌.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/theme.dart';
import 'core/a11y.dart';
import 'core/logger.dart';
import 'data/db.dart';
import 'data/prefs.dart';
import 'domain/gaze/gaze_repo.dart';
import 'domain/gaze/mock_gaze.dart';
import 'domain/tts/tts_service.dart';
import 'domain/sos/sos_service.dart';
import 'domain/models/settings_model.dart';
import 'ui/screens/camera_screen.dart';
import 'ui/screens/settings_screen.dart';
import 'ui/screens/calibration_screen.dart';
import 'ui/screens/board_editor_screen.dart';
import 'ui/screens/sos_detail_screen.dart';
import 'ui/a11y/font_scaler.dart';
import 'ui/screens/eye_debug_screen.dart';

class AppRoot extends StatefulWidget {
  const AppRoot({super.key});

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> {
  late final Future<_AppBundle> _init;

  @override
  void initState() {
    super.initState();
    _init = _bootstrap();
  }

  Future<_AppBundle> _bootstrap() async {
    final prefs = await SharedPreferences.getInstance();
    final settings = await SettingsStore.load(prefs);
    final db = await LogsDb.open();
    final logger = AppLogger(db);
    final tts = TtsService(logger: logger);
    await tts.init(
      language: settings.locale,
      rate: settings.ttsRate,
      pitch: settings.ttsPitch,
      voice: settings.ttsVoice,
    );
    // 플랫폼별 가용성 고려: 안드로이드 + 설정 해제 시에만 온디바이스 경로 선택
    final isAndroid = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    final gaze = (!settings.mockGaze && isAndroid)
        ? selectGazeRepo(onDevicePreferred: true)
        : MockGaze();
    // 권한 요청
    await _ensurePermissions(tts, settings);
    return _AppBundle(
      prefs: prefs,
      settings: settings,
      logger: logger,
      tts: tts,
      gaze: gaze,
      sos: SosService(logger: logger, tts: tts),
    );
  }

  Future<void> _ensurePermissions(TtsService tts, SettingsModel settings) async {
    if (kIsWeb) return; // 웹에서는 권한 요청 스킵
    final statuses = await [
      Permission.camera,
      Permission.phone,
    ].request();
    final camOk = statuses[Permission.camera]?.isGranted ?? false;
    if (!camOk) {
      await tts.speak(settings.locale == 'ko'
          ? '카메라 권한이 없어 모의 시선을 사용합니다. 화면을 탭하거나 드래그하세요.'
          : 'Camera denied. Using mock gaze. Tap or drag the screen.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_AppBundle>(
      future: _init,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: buildAppTheme(highContrast: false, brightness: Brightness.light),
            home: Scaffold(
              appBar: AppBar(title: const Text('시작 오류')),
              body: Padding(
                padding: const EdgeInsets.all(16),
                child: SingleChildScrollView(child: Text('초기화 중 오류가 발생했습니다.\n\n${snapshot.error}')),
              ),
            ),
          );
        }
        if (!snapshot.hasData) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: buildAppTheme(highContrast: false, brightness: Brightness.light),
            home: const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            ),
          );
        }
        final bundle = snapshot.data!;
        return AppScope(
          bundle: bundle,
          child: SettingsScope(
            settings: bundle.settings,
            onChanged: () async {
              await SettingsStore.save(bundle.prefs, bundle.settings);
              if (!mounted) return;
              setState(() {});
            },
            child: Builder(builder: (context) {
              final s = SettingsScope.of(context);
              return MaterialApp(
                debugShowCheckedModeBanner: false,
                title: s.locale == 'ko' ? '에스크 아이' : 'Ask Eye',
                themeMode: s.darkMode ? ThemeMode.dark : ThemeMode.light,
                theme: buildAppTheme(
                    highContrast: s.highContrast, brightness: Brightness.light),
                darkTheme: buildAppTheme(
                    highContrast: s.highContrast, brightness: Brightness.dark),
                home: const CameraScreen(),
                onGenerateRoute: (rs) {
                  switch (rs.name) {
                    case '/camera':
                      return MaterialPageRoute(builder: (_) => const CameraScreen(), settings: rs);
                    case '/debug':
                      return MaterialPageRoute(builder: (_) => const EyeDebugScreen(), settings: rs);
                    case '/settings':
                      return MaterialPageRoute(builder: (_) => const SettingsScreen(), settings: rs);
                    case '/calibration':
                      return MaterialPageRoute(builder: (_) => const CalibrationScreen(), settings: rs);
                    case '/editor':
                      return MaterialPageRoute(builder: (_) => const BoardEditorScreen(), settings: rs);
                    case '/sos_detail':
                      return MaterialPageRoute(builder: (_) => const SosDetailScreen(), settings: rs);
                    default:
                      return null;
                  }
                },
                onUnknownRoute: (rs) => MaterialPageRoute(builder: (_) => const CameraScreen(), settings: rs),
                builder: (context, child) => FontScaler(scale: s.fontScale, child: child ?? const SizedBox()),
              );
            }),
          ),
        );
      },
    );
  }
}

class _AppBundle {
  final SharedPreferences prefs;
  final SettingsModel settings;
  final AppLogger logger;
  final TtsService tts;
  final GazeRepo gaze;
  final SosService sos;
  _AppBundle({
    required this.prefs,
    required this.settings,
    required this.logger,
    required this.tts,
    required this.gaze,
    required this.sos,
  });
}

class AppScope extends InheritedWidget {
  final _AppBundle bundle;
  const AppScope({super.key, required this.bundle, required super.child});

  static _AppBundle of(BuildContext context) {
    final w = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(w != null, 'AppScope not found');
    return w!.bundle;
  }

  @override
  bool updateShouldNotify(covariant AppScope oldWidget) {
    return bundle != oldWidget.bundle;
  }
}

class SettingsScope extends InheritedNotifier<ValueNotifier<int>> {
  final SettingsModel settings;
  final Future<void> Function() onChanged;
  SettingsScope(
      {super.key,
      required this.settings,
      required this.onChanged,
      required Widget child})
      : super(notifier: ValueNotifier(0), child: child);

  static SettingsModel of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<SettingsScope>();
    if (scope == null) {
      // Fallback to sensible defaults so UI can render even if scope isn't in tree yet.
      return SettingsModel(
        locale: 'ko',
        dwellMs: 2000,
        highContrast: false,
        fontScale: 1.0,
        darkMode: false,
        cursorSize: 32,
        cursorColor: 0xFF00BCD4,
        ttsRate: 0.5,
        ttsPitch: 1.0,
        ttsVoice: null,
        mockGaze: true,
        sosMode: SosMode.both,
        calibrationJson: null,
        gazeReadout: false,
      );
    }
    return scope.settings;
  }

  static Future<void> save(BuildContext context) async {
    final scope = context.getInheritedWidgetOfExactType<SettingsScope>();
    if (scope != null) {
      (scope.notifier as ValueNotifier<int>).value++;
      await scope.onChanged();
    }
  }
}
