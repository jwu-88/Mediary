import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediary/liquid_glass_search_field.dart';

void main() {
  testWidgets('uses the navigation glass recipe and capsule radius', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light(useMaterial3: true),
        home: Scaffold(
          backgroundColor: const Color(0xFF6BA8C8),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: LiquidGlassSearchField(
                controller: controller,
                hintText: 'Search Medications',
                useLiquidGlass: true,
              ),
            ),
          ),
        ),
      ),
    );

    final surface = tester.widget<Container>(
      find.byKey(const Key('liquidGlassSearchSurface')),
    );
    final decoration = surface.decoration! as BoxDecoration;
    final gradient = decoration.gradient! as LinearGradient;
    final border = decoration.border! as Border;

    expect(
      tester.getSize(find.byKey(const Key('liquidGlassSearchSurface'))).height,
      52,
    );
    expect(decoration.borderRadius, BorderRadius.circular(32));
    expect(gradient.colors.every((color) => color.a < 1), isTrue);
    expect(border.top, border.right);
    expect(border.right, border.bottom);
    expect(border.bottom, border.left);
    expect(border.top.width, 1);
    expect(border.top.color.a, greaterThan(.75));
    expect(find.byType(BackdropFilter), findsOneWidget);
  });

  testWidgets('search text and clear action remain interactive', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    String? query;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LiquidGlassSearchField(
            controller: controller,
            hintText: 'Search Medications',
            textFieldKey: const Key('searchField'),
            onChanged: (value) => query = value,
            useLiquidGlass: true,
          ),
        ),
      ),
    );

    await tester.enterText(find.byKey(const Key('searchField')), 'amoxicillin');
    await tester.pump();
    expect(controller.text, 'amoxicillin');
    expect(query, 'amoxicillin');

    await tester.tap(find.byKey(const Key('liquidGlassSearchClearButton')));
    await tester.pump();
    expect(controller.text, isEmpty);
    expect(query, isEmpty);
  });
}
