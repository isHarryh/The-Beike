# AGENTS.md

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

### Coding Guidelines for Pages

When creating or modifying Flutter UI pages in the `lib/pages/` directory, please adhere to the following guidelines:

1. **Unified App Bar Design**: Generally, each page should use our custom app bar defined in `lib/utils/app_bar.dart`.
2. **Dynamic Theming**: It's recommended to use `Theme.of(context)` to obtain colors and text styles.
