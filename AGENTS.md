# AGENTS.md

AI coding agents must read and understand this document before they can contribute to the project.

## Project Overview

This project `The-Beike` is a Flutter application.

### Foundations

- **Pages and Routing**: The UI is structured around pages located in the `lib/pages/` directory. Router can be found in `lib/router.dart`.
- **Service System**: We use service system to interact with external data sources. All services are defined in the `lib/services/` directory, and a service provider (see `lib/services/provider.dart`) maintains the integration of all services.
- **Data Types**: We use `json_annotation` package and our own abstract base class (see `lib/types/base.dart`) to define data types. After modifying data types, remember to run `dart run build_runner build --delete-conflicting-outputs` to generate code.

### Code Style

- **Consistency**: You should read the existing code in the codebase and follow their coding conventions.
- **Imports**: Import order is dart packages first, third-party packages second, our code third. If you wants to import a dart file outside the current file's directory, use absolute path like `import '/foo/bar.dart';`. If you wants to import a dart file right next to the current file, use shortcut like `import 'xxx.dart';`.

## Coding Guidelines

### Working with Pages

When creating or modifying Flutter UI pages in the `lib/pages/` directory, please adhere to the following guidelines:

1. **Unified App Bar Design**: Generally, each page should use our custom app bar defined in `lib/utils/app_bar.dart`.
2. **Dynamic Theming**: It's recommended to use `Theme.of(context)` to obtain colors and text styles.

### Working with dio

When handling network requests using the `dio` package, please read the `/using-dio` skill first.

## Knowledge

### Dart SDK Recent Notable Changes

- Flutter ↔ Dart mapping: 3.38 → 3.10, 3.41 → 3.11, 3.44 → 3.12.
- Dart 3.11: `dart:io` Unix domain sockets on Windows; dart2wasm dropped `dart:js_util`; pub workspace globs (`pkgs/*`).
- Dart 3.12: `dart:js_interop` accepted various new changes; supported private named parameters on initializing formals and primary constructor parameters.

### Flutter SDK Recent Notable Changes

- Flutter 3.41: default mouse cursor of Material interactive widgets became arrow on non-web (see Known Migrations); M3 color tokens updated (minor visual changes); `containsSemantics` → `isSemantics`, `findChildIndexCallback` → `findItemIndexCallback` (auto-fixable); `FontWeight` now drives the variable-font weight axis.
- Flutter 3.44: built-in Kotlin migration for AGP 9; `IconData` is now `final`; `onReorder` and `cacheExtent`/`cacheExtentStyle` deprecated (use `ScrollCacheExtent`); `CupertinoPageTransitionsBuilder` moved to `cupertino.dart`; Xcode ≥ 15 required, SwiftPM on by default in stable; new templates use AGP 9.0.1 / Gradle 9.1.0 / minSdk 24 / targetSdk 36.
- New APIs worth knowing: `CarouselView`, `Navigator.popUntilWithResult`, `ScrollCacheExtent`, `SizedBox.square()`, `FormState.fields`, `ThemeMode.isDark/isLight/isSystem`.

### Known Migrations

- **Cursor behavior** (Flutter ≥ 3.41, PR #171796): Material interactive widgets (buttons, InkWell, FAB, chips, checkbox/switch/slider/radio, dropdowns, popup menus, list tiles) default to `WidgetStateMouseCursor.adaptiveClickable` (hand cursor on web only, arrow on desktop). This is deliberate desktop behavior, not a bug.
  - In order to restore the hand cursor on desktop, we have already set `WidgetStatePropertyAll(WidgetStateMouseCursor.clickable)` (hand when enabled, arrow when disabled) via `{widgetName}Theme` in `lib/main.dart` globally.
  - However, `InkWell` and `FilterChip` have no theme slot so we need to manually set `mouseCursor` per widget. Gotcha: `ListTile` always wraps itself in an inner `InkWell`, whose `MouseRegion` cursor wins over any outer `InkWell`. A `ListTile` without `onTap` resolves to disabled → arrow; force `mouseCursor: SystemMouseCursors.click` on it.
