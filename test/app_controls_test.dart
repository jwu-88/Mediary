import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediary/app_controls.dart';
import 'package:mediary/app_theme.dart';
import 'package:mediary/liquid_glass_search_field.dart';

void main() {
  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    double scale = 1,
    bool reducedMotion = false,
  }) => tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: MediaQuery(
        data: MediaQueryData(
          textScaler: TextScaler.linear(scale),
          disableAnimations: reducedMotion,
        ),
        child: Scaffold(body: Center(child: child)),
      ),
    ),
  );

  testWidgets('all action priorities share touch size and readable text', (
    tester,
  ) async {
    await pump(
      tester,
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final variant in AppButtonVariant.values)
            AppButton(
              key: ValueKey(variant),
              label: 'Continue',
              variant: variant,
              onPressed: () {},
            ),
        ],
      ),
    );
    for (final variant in AppButtonVariant.values) {
      final size = tester.getSize(find.byKey(ValueKey(variant)));
      expect(size.height, 48);
      expect(size.width, greaterThanOrEqualTo(64));
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'starts synchronously and blocks repeated taps until completion',
    (tester) async {
      final completion = Completer<void>();
      var calls = 0;
      await pump(
        tester,
        AppButton(
          label: 'Save changes',
          onPressed: () {
            calls++;
            return completion.future;
          },
        ),
      );
      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      button.onPressed!();
      expect(calls, 1);
      button.onPressed!();
      expect(calls, 1);
      await tester.pump();
      expect(find.text('Save changes'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      completion.complete();
      await tester.pumpAndSettle();
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull,
      );
    },
  );

  testWidgets('a failed async action recovers and reports the error', (
    tester,
  ) async {
    Object? error;
    await pump(
      tester,
      AppButton(
        label: 'Retry',
        onPressed: () => Future<void>.error(StateError('failed')),
        onError: (value, _) => error = value,
      ),
    );
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(error, isA<StateError>());
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('busy actions retain contrast and reject taps', (tester) async {
    var calls = 0;
    await pump(
      tester,
      AppButton(label: 'Save', busy: true, onPressed: () => calls++),
    );
    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(
      button.style!.backgroundColor!.resolve({WidgetState.disabled}),
      AppTheme.light.colorScheme.primary,
    );
    expect(
      button.style!.foregroundColor!.resolve({WidgetState.disabled}),
      AppTheme.light.colorScheme.onPrimary,
    );
    await tester.tap(find.text('Save'));
    expect(calls, 0);
  });

  testWidgets('keyboard activation and focus share the touch action', (
    tester,
  ) async {
    var calls = 0;
    await pump(tester, AppButton(label: 'Continue', onPressed: () => calls++));
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.style!.side!.resolve({WidgetState.focused})!.width, 2);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(calls, 1);
  });

  testWidgets(
    'large text fits narrow actions and preserves complete semantics',
    (tester) async {
      const label = 'Choose a different medication from your photo library';
      final semantics = tester.ensureSemantics();

      await pump(
        tester,
        SizedBox(
          width: 180,
          child: AppButton(label: label, icon: Icons.photo, onPressed: () {}),
        ),
        scale: 3,
      );
      expect(tester.getSize(find.byType(AppButton)).height, lessThan(150));
      expect(find.bySemanticsLabel(label), findsOneWidget);
      semantics.dispose();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('search grows with text size and clearing keeps input focused', (
    tester,
  ) async {
    final controller = TextEditingController(text: 'Aspirin');
    addTearDown(controller.dispose);
    await pump(
      tester,
      SizedBox(
        width: 300,
        child: LiquidGlassSearchField(
          controller: controller,
          hintText: 'Search medications',
          useLiquidGlass: false,
        ),
      ),
      scale: 3,
    );
    expect(
      tester.getSize(find.byKey(const Key('liquidGlassSearchSurface'))).height,
      greaterThan(80),
    );
    expect(
      tester.getSize(find.byKey(const Key('liquidGlassSearchClearButton'))),
      const Size(44, 44),
    );
    await tester.tap(find.byKey(const Key('liquidGlassSearchClearButton')));
    await tester.pumpAndSettle();
    expect(controller.text, isEmpty);
    expect(
      tester.widget<TextField>(find.byType(TextField)).focusNode!.hasFocus,
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'busy icon actions retain their accessible label without tooltips',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await pump(
        tester,
        AppIconButton(
          icon: Icons.delete_outline,
          tooltip: 'Remove medication',
          showTooltip: false,
          busy: true,
          onPressed: () {},
        ),
      );
      expect(find.bySemanticsLabel('Remove medication'), findsOneWidget);
      expect(
        tester.widget<IconButton>(find.byType(IconButton)).onPressed,
        isNull,
      );
      semantics.dispose();
    },
  );

  testWidgets('reduced motion turns off button transitions', (tester) async {
    await pump(
      tester,
      AppButton(label: 'Continue', onPressed: () {}),
      reducedMotion: true,
    );
    expect(
      tester
          .widget<FilledButton>(find.byType(FilledButton))
          .style!
          .animationDuration,
      Duration.zero,
    );
  });
}
