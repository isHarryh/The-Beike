// Copyright (c) 2025, Harry Huang

import 'package:flutter/material.dart';
import 'services/provider.dart';
import 'types/preferences.dart';
import 'utils/meta_info.dart';
import 'router.dart';

void main() async {
  // Initialize services before running the GUI
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize app info first (meta information like version, platform, device)
  await MetaInfo.instance.initialize();
  // Initialize service provider
  await ServiceProvider.instance.initializeServices();
  // Run the GUI application
  runApp(const Main());
}

class ThemeManager {
  static ThemeMode _currentThemeMode = ThemeMode.system;
  static void Function(ThemeMode)? _updateCallback;

  static ThemeMode get currentThemeMode => _currentThemeMode;

  static void initialize(
    ThemeMode initialMode,
    void Function(ThemeMode) updateCallback,
  ) {
    _currentThemeMode = initialMode;
    _updateCallback = updateCallback;
  }

  static void updateThemeMode(ThemeMode themeMode) {
    _currentThemeMode = themeMode;
    _updateCallback?.call(themeMode);
  }
}

class Main extends StatefulWidget {
  const Main({super.key});

  @override
  State<Main> createState() => _MainState();
}

class _MainState extends State<Main> {
  final ServiceProvider _serviceProvider = ServiceProvider.instance;
  late ThemeMode _themeMode;

  _MainState() {
    _themeMode =
        _serviceProvider.storeService
            .getPref<AppSettings>('app_settings', AppSettings.fromJson)
            ?.themeMode ??
        ThemeMode.system;

    ThemeManager.initialize(_themeMode, (ThemeMode themeMode) {
      setState(() {
        _themeMode = themeMode;
      });
      final appSettings = AppSettings(themeMode: themeMode);
      _serviceProvider.storeService.putPref<AppSettings>(
        'app_settings',
        appSettings,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'TheBeike',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color.fromRGBO(0, 91, 148, 1.0),
          brightness: Brightness.light,
          dynamicSchemeVariant: DynamicSchemeVariant.rainbow,
        ),
        fontFamily: 'SourceHanSansSC',
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color.fromRGBO(0, 91, 148, 1.0),
          brightness: Brightness.dark,
          dynamicSchemeVariant: DynamicSchemeVariant.rainbow,
        ),
        fontFamily: 'SourceHanSansSC',
        useMaterial3: true,
      ),
      themeMode: _themeMode,
      routerConfig: AppRouter.router.config(),
    );
  }
}
