import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediary/app_theme.dart';
import 'package:mediary/liquid_glass_accent_selector.dart';

void main() {
  testWidgets('renders five equal circular glass swatches', (tester) async {
    await _pumpSelector(tester);

    final selector = tester.widget<Container>(
      find.byKey(const Key('accentColorSelector')),
    );
    final decoration = selector.decoration! as BoxDecoration;
    final optionSizes = [
      'accentOptionBlue',
      'accentOptionIndigo',
      'accentOptionPurple',
      'accentOptionTeal',
      'accentOptionOrange',
    ].map((key) => tester.getSize(find.byKey(Key(key)))).toList();

    expect(selector.constraints!.maxHeight, 68);
    expect(decoration.borderRadius, BorderRadius.circular(34));
    expect(decoration.gradient, isNull);
    expect(decoration.color, isNotNull);
    expect(optionSizes.toSet(), hasLength(1));
    expect(optionSizes.first.width, optionSizes.first.height);
    expect(optionSizes.first, const Size.square(50));
    expect(find.byType(BackdropFilter), findsNWidgets(6));
  });

  testWidgets('defaults to blue and exposes accessible selection', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await _pumpSelector(tester);

    expect(
      tester.getSemantics(find.byKey(const Key('accentOptionBlue'))),
      matchesSemantics(
        label: 'Blue',
        value: 'Selected',
        isButton: true,
        hasSelectedState: true,
        isSelected: true,
        isInMutuallyExclusiveGroup: true,
        hasTapAction: true,
      ),
    );
    expect(
      tester.getSemantics(find.byKey(const Key('accentOptionPurple'))),
      matchesSemantics(
        label: 'Purple',
        value: 'Not selected',
        isButton: true,
        hasSelectedState: true,
        isInMutuallyExclusiveGroup: true,
        hasTapAction: true,
      ),
    );
    expect(find.byKey(const Key('accentSelectedCheck')), findsOneWidget);

    semantics.dispose();
  });

  testWidgets('reports a newly selected accent color', (tester) async {
    AppAccentColor? changedAccent;
    await _pumpSelector(
      tester,
      value: AppAccentColor.indigo,
      onChanged: (accent) => changedAccent = accent,
    );

    await tester.tap(find.byKey(const Key('accentOptionOrange')));

    expect(changedAccent, AppAccentColor.orange);
  });

  testWidgets('adapts its glass treatment for dark appearance', (tester) async {
    await _pumpSelector(tester, brightness: Brightness.dark);

    final selector = tester.widget<Container>(
      find.byKey(const Key('accentColorSelector')),
    );
    final decoration = selector.decoration! as BoxDecoration;
    expect(decoration.gradient, isNull);
    expect(decoration.color, isNotNull);
    expect(find.byKey(const Key('accentOptionTeal')), findsOneWidget);
  });
}

Future<void> _pumpSelector(
  WidgetTester tester, {
  AppAccentColor? value,
  ValueChanged<AppAccentColor>? onChanged,
  Brightness brightness = Brightness.light,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      theme: brightness == Brightness.light
          ? ThemeData.light(useMaterial3: true)
          : ThemeData.dark(useMaterial3: true),
      home: Scaffold(
        backgroundColor: brightness == Brightness.light
            ? const Color(0xFF79AFC8)
            : const Color(0xFF17212B),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: LiquidGlassAccentSelector(
              value: value ?? AppAccentColor.blue,
              onChanged: onChanged ?? (_) {},
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
