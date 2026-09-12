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
    final border = decoration.border! as Border;

    expect(
      tester.getSize(find.byKey(const Key('liquidGlassSearchSurface'))).height,
      52,
    );
    expect(decoration.borderRadius, BorderRadius.circular(32));
    expect(decoration.gradient, isNull);
    expect(decoration.color, isNotNull);
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

  testWidgets('moves listeners when the text controller changes', (
    tester,
  ) async {
    final firstController = _TrackingTextEditingController(text: 'First');
    final secondController = _TrackingTextEditingController();
    addTearDown(firstController.dispose);
    addTearDown(secondController.dispose);

    Widget buildSearch(TextEditingController controller) {
      return MaterialApp(
        home: Scaffold(
          body: LiquidGlassSearchField(
            key: const Key('search'),
            controller: controller,
            hintText: 'Search Medications',
            useLiquidGlass: true,
          ),
        ),
      );
    }

    await tester.pumpWidget(buildSearch(firstController));
    expect(firstController.listenerCount, greaterThan(0));
    expect(
      find.byKey(const Key('liquidGlassSearchClearButton')),
      findsOneWidget,
    );

    await tester.pumpWidget(buildSearch(secondController));
    await tester.pump();

    expect(firstController.listenerCount, 0);
    expect(secondController.listenerCount, greaterThan(0));
    expect(find.byKey(const Key('liquidGlassSearchClearButton')), findsNothing);

    secondController.text = 'Second';
    await tester.pump();
    expect(
      find.byKey(const Key('liquidGlassSearchClearButton')),
      findsOneWidget,
    );
  });
}

class _TrackingTextEditingController extends TextEditingController {
  _TrackingTextEditingController({super.text});

  final Set<VoidCallback> _listeners = {};

  int get listenerCount => _listeners.length;

  @override
  void addListener(VoidCallback listener) {
    _listeners.add(listener);
    super.addListener(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
    super.removeListener(listener);
  }
}
