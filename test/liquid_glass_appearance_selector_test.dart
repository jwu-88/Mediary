import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediary/liquid_glass_appearance_selector.dart';

void main() {
  testWidgets('renders three equal capsule glass options', (tester) async {
    await _pumpSelector(tester, value: ThemeMode.system);

    final selector = tester.widget<Container>(
      find.byKey(const Key('appearanceModeSelector')),
    );
    final decoration = selector.decoration! as BoxDecoration;
    final gradient = decoration.gradient! as LinearGradient;
    final lightSize = tester.getSize(
      find.byKey(const Key('appearanceOptionLight')),
    );
    final darkSize = tester.getSize(
      find.byKey(const Key('appearanceOptionDark')),
    );
    final systemSize = tester.getSize(
      find.byKey(const Key('appearanceOptionSystem')),
    );

    expect(selector.constraints!.maxHeight, 64);
    expect(decoration.borderRadius, BorderRadius.circular(32));
    expect(gradient.colors.every((color) => color.a < 1), isTrue);
    expect(lightSize, darkSize);
    expect(darkSize, systemSize);
    expect(find.byType(BackdropFilter), findsNWidgets(4));
  });

  testWidgets('announces selection and reports a changed mode', (tester) async {
    ThemeMode? changedMode;
    final semantics = tester.ensureSemantics();

    await _pumpSelector(
      tester,
      value: ThemeMode.system,
      onChanged: (mode) => changedMode = mode,
    );

    expect(
      tester.getSemantics(find.byKey(const Key('appearanceOptionSystem'))),
      matchesSemantics(
        label: 'System',
        value: 'Selected',
        isButton: true,
        hasSelectedState: true,
        isSelected: true,
        isInMutuallyExclusiveGroup: true,
        hasTapAction: true,
      ),
    );
    expect(
      tester.getSemantics(find.byKey(const Key('appearanceOptionLight'))),
      matchesSemantics(
        label: 'Light',
        value: 'Not selected',
        isButton: true,
        hasSelectedState: true,
        isInMutuallyExclusiveGroup: true,
        hasTapAction: true,
      ),
    );

    await tester.tap(find.byKey(const Key('appearanceOptionDark')));
    expect(changedMode, ThemeMode.dark);

    semantics.dispose();
  });
}

Future<void> _pumpSelector(
  WidgetTester tester, {
  required ThemeMode value,
  ValueChanged<ThemeMode>? onChanged,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData.light(useMaterial3: true),
      home: Scaffold(
        backgroundColor: const Color(0xFF79AFC8),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: LiquidGlassAppearanceSelector(
              value: value,
              onChanged: onChanged ?? (_) {},
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
