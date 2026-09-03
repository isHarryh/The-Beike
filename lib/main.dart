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
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      themeMode: _themeMode,
      routerConfig: AppRouter.router.config(),
    );
  }

  /// Builds the app theme.
  ThemeData _buildTheme(Brightness brightness) {
    final ThemeData base = ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color.fromRGBO(0, 91, 148, 1.0),
        brightness: brightness,
        dynamicSchemeVariant: DynamicSchemeVariant.rainbow,
      ),
      fontFamily: 'SourceHanSansSC',
      useMaterial3: true,
    );
    // Flutter 3.41 changed the default mouse cursor of interactive widgets
    // from the click (hand) cursor to the arrow cursor on desktop platforms.
    // Restore the previous behavior for a consistent desktop experience.
    const WidgetStateProperty<MouseCursor> clickableCursor =
        WidgetStatePropertyAll(WidgetStateMouseCursor.clickable);
    return base.copyWith(
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(mouseCursor: clickableCursor),
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(mouseCursor: clickableCursor),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(mouseCursor: clickableCursor),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(mouseCursor: clickableCursor),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(mouseCursor: clickableCursor),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        mouseCursor: clickableCursor,
      ),
      checkboxTheme: CheckboxThemeData(mouseCursor: clickableCursor),
      switchTheme: SwitchThemeData(mouseCursor: clickableCursor),
      sliderTheme: SliderThemeData(mouseCursor: clickableCursor),
      radioTheme: RadioThemeData(mouseCursor: clickableCursor),
      popupMenuTheme: PopupMenuThemeData(mouseCursor: clickableCursor),
      listTileTheme: ListTileThemeData(mouseCursor: clickableCursor),
    );
  }
}
