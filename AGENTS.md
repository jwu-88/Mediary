# Repository Guidelines

## Project Structure & Module Organization

This is a single Flutter application. Keep Dart application code in `lib/`; the current entry point is `lib/main.dart`. Put widget and unit tests in `test/`, mirroring the source file where practical (for example, `lib/widgets/counter.dart` → `test/widgets/counter_test.dart`).

Platform runners live in `android/`, `ios/`, `web/`, `linux/`, `macos/`, and `windows/`. Change them only for platform-specific configuration. Declare packages, app metadata, and bundled assets in `pubspec.yaml`; add assets under a clearly named top-level directory such as `assets/images/` and register them there.

## Build, Test, and Development Commands

- `flutter pub get` — fetch dependencies after changing `pubspec.yaml`.
- `flutter run` — run the app on a connected device or selected simulator.
- `flutter analyze` — run the Dart analyzer and the configured Flutter lints.
- `flutter test` — run the `flutter_test` suite in `test/`.
- `dart format .` — format all Dart code before submitting changes.
- `flutter build <platform>` — create a release build, for example `flutter build apk` or `flutter build web`.

## Coding Style & Naming Conventions

Use the formatter’s standard two-space indentation; do not manually align code against its output. Follow Dart conventions: `PascalCase` for classes, enums, and widgets; `camelCase` for members, functions, and variables; and `snake_case.dart` for file names. Keep widgets focused, use `const` constructors where possible, and avoid logic-heavy `build` methods. The project includes `flutter_lints`; resolve analyzer warnings instead of broadly disabling rules.

## Testing Guidelines

Write tests with `flutter_test`. Name files `*_test.dart` and tests as observable behavior, such as `testWidgets('increments counter when add is tapped', ...)`. Cover new behavior and regressions; no coverage threshold is currently configured. Run `flutter analyze` and `flutter test` before opening a pull request.

## Commit & Pull Request Guidelines

The history is minimal (`Add files`, `first commit`), so use concise, imperative commit subjects such as `Add profile screen` or `Fix counter state`. Keep commits narrowly scoped. Pull requests should explain the user-visible change, list verification commands, link relevant issues, and include screenshots or recordings for UI changes. Do not commit generated build output, credentials, or service configuration secrets.
