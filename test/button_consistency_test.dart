import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediary/app_interactions.dart';
import 'package:mediary/app_theme.dart';
import 'package:mediary/in_app_page.dart';
import 'package:mediary/liquid_glass_tab_bar.dart';

void main() {
  test('shared button metrics define the common control geometry', () {
    expect(AppButtonMetrics.height, 48);
    expect(AppButtonMetrics.minWidth, 64);
    expect(AppButtonMetrics.compactHeight, 44);
    expect(AppButtonMetrics.iconButtonSize, 44);
    expect(AppButtonMetrics.radius, AppRadii.standard);
    expect(AppButtonMetrics.iconGap, 8);
    expect(AppButtonMetrics.loadingIndicatorSize, 20);
    expect(AppButtonMetrics.disabledOpacity, .46);
    expect(AppButtonMetrics.labelStyle.fontSize, 15);
    expect(AppButtonMetrics.labelStyle.fontWeight, FontWeight.w600);
  });

  testWidgets('material button hierarchy shares size, radius, and typography', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Row(
          children: [
            ElevatedButton(onPressed: () {}, child: const Text('Primary')),
            FilledButton(onPressed: () {}, child: const Text('Filled')),
            OutlinedButton(onPressed: () {}, child: const Text('Secondary')),
            TextButton(onPressed: () {}, child: const Text('Tertiary')),
            IconButton(onPressed: () {}, icon: const Icon(Icons.add)),
          ],
        ),
      ),
    );

    final styles = [
      AppTheme.light.elevatedButtonTheme.style!,
      AppTheme.light.filledButtonTheme.style!,
      AppTheme.light.outlinedButtonTheme.style!,
      AppTheme.light.textButtonTheme.style!,
    ];
    for (final style in styles) {
      expect(style.minimumSize!.resolve({})!.height, AppButtonMetrics.height);
      expect(
        style.padding!.resolve({})!.horizontal,
        AppButtonMetrics.horizontalPadding * 2,
      );
      expect(
        style.textStyle!.resolve({})!.fontSize,
        AppButtonMetrics.labelStyle.fontSize,
      );
    }

    final iconStyle = AppTheme.light.iconButtonTheme.style!;
    expect(
      iconStyle.minimumSize!.resolve({}),
      const Size.square(AppButtonMetrics.iconButtonSize),
    );
  });

  testWidgets('responsive and in-app controls use shared touch geometry', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: ResponsiveCupertinoButton(
            onPressed: () {},
            child: const Text('Continue'),
          ),
        ),
      ),
    );

    final responsive = tester.getSize(find.byType(AppPressable));
    expect(responsive.height, greaterThanOrEqualTo(AppButtonMetrics.height));
    final pressable = tester.widget<AppPressable>(find.byType(AppPressable));
    expect(
      pressable.borderRadius,
      BorderRadius.circular(AppButtonMetrics.radius),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: InAppOptionPage<String>(
          title: 'Choose one',
          options: const [InAppPageOption(label: 'Option', value: 'option')],
        ),
      ),
    );
    expect(find.byKey(const Key('inAppOption-Option')), findsOneWidget);
  });

  testWidgets('custom pressables share loading and disabled feedback', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: AppPressable(
          enabled: false,
          busy: true,
          onPressed: () => calls += 1,
          child: const Text('Save'),
        ),
      ),
    );

    expect(
      find.byKey(const Key('appPressableLoadingIndicator')),
      findsOneWidget,
    );
    expect(
      tester
          .widget<AnimatedOpacity>(find.byKey(const Key('appPressableOpacity')))
          .opacity,
      AppButtonMetrics.disabledOpacity,
    );

    await tester.tap(find.byType(AppPressable));
    expect(calls, 0);
  });

  testWidgets('tab bar keeps a consistent navigation control height', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          bottomNavigationBar: LiquidGlassTabBar(
            currentIndex: 0,
            onTap: (_) {},
          ),
        ),
      ),
    );

    expect(
      tester.getSize(find.byKey(const Key('liquidGlassTabBar'))).height,
      AppButtonMetrics.navigationHeight,
    );
  });
}
