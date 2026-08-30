import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediary/app_theme.dart';

void main() {
  testWidgets('brightness changes interpolate without an early black frame', (
    tester,
  ) async {
    var mode = ThemeMode.light;

    Widget buildApp() =>
        _TransitionTestApp(mode: mode, accent: AppAccentColor.blue);

    await tester.pumpWidget(buildApp());
    expect(_backgroundColor(tester), AppColors.lightBackground);

    mode = ThemeMode.dark;
    await tester.pumpWidget(buildApp());
    await tester.pump(AppTheme.transitionDuration * .35);

    final inProgress = _backgroundColor(tester);
    expect(inProgress, isNot(AppColors.lightBackground));
    expect(inProgress, isNot(AppColors.darkBackground));
    expect(inProgress, isNot(Colors.black));

    await tester.pumpAndSettle();
    expect(_backgroundColor(tester), AppColors.darkBackground);
  });

  testWidgets('accent changes interpolate instead of switching abruptly', (
    tester,
  ) async {
    var accent = AppAccentColor.blue;

    Widget buildApp() =>
        _TransitionTestApp(mode: ThemeMode.light, accent: accent);

    await tester.pumpWidget(buildApp());
    expect(_primaryColor(tester), AppAccentColor.blue.light);

    accent = AppAccentColor.purple;
    await tester.pumpWidget(buildApp());
    await tester.pump(AppTheme.transitionDuration * .5);

    final inProgress = _primaryColor(tester);
    expect(inProgress, isNot(AppAccentColor.blue.light));
    expect(inProgress, isNot(AppAccentColor.purple.light));
    expect(inProgress, isNot(Colors.black));

    await tester.pumpAndSettle();
    expect(_primaryColor(tester), AppAccentColor.purple.light);
  });

  testWidgets('system brightness changes use the same smooth transition', (
    tester,
  ) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    addTearDown(tester.platformDispatcher.clearAllTestValues);

    await tester.pumpWidget(
      const _TransitionTestApp(
        mode: ThemeMode.system,
        accent: AppAccentColor.blue,
      ),
    );
    expect(_backgroundColor(tester), AppColors.lightBackground);

    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    await tester.pump();
    await tester.pump(AppTheme.transitionDuration * .35);

    final inProgress = _backgroundColor(tester);
    expect(inProgress, isNot(AppColors.lightBackground));
    expect(inProgress, isNot(AppColors.darkBackground));
    expect(inProgress, isNot(Colors.black));

    await tester.pumpAndSettle();
    expect(_backgroundColor(tester), AppColors.darkBackground);
  });
}

class _TransitionTestApp extends StatelessWidget {
  const _TransitionTestApp({required this.mode, required this.accent});

  final ThemeMode mode;
  final AppAccentColor accent;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: AppTheme.lightFor(accent),
      darkTheme: AppTheme.darkFor(accent),
      themeMode: mode,
      themeAnimationDuration: AppTheme.transitionDuration,
      themeAnimationCurve: AppTheme.transitionCurve,
      builder: (context, child) =>
          AppThemeTransitionSurface(child: child ?? const SizedBox.shrink()),
      home: const Scaffold(body: SizedBox.expand()),
    );
  }
}

Color _backgroundColor(WidgetTester tester) {
  return tester
      .widget<ColoredBox>(find.byKey(const Key('appThemeTransitionSurface')))
      .color;
}

Color _primaryColor(WidgetTester tester) {
  final context = tester.element(
    find.byKey(const Key('appThemeTransitionSurface')),
  );
  return Theme.of(context).colorScheme.primary;
}
