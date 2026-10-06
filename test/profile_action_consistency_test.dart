import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediary/app_controls.dart';
import 'package:mediary/app_theme.dart';
import 'package:mediary/profile_screen.dart';
import 'package:mediary/settings_screen.dart';
import 'package:mediary/weekly_report_screen.dart';

void main() {
  Widget harness(Widget child, {double textScale = 1}) => MaterialApp(
    theme: AppTheme.light,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: TextScaler.linear(textScale)),
      child: child!,
    ),
    home: child,
  );

  void narrowScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets(
    'large-text profile editing retains visible actions and saving feedback',
    (tester) async {
      narrowScreen(tester);
      final saving = Completer<void>();
      var saveCalls = 0;
      await tester.pumpWidget(
        harness(
          ProfileScreen(
            email: 'person@example.com',
            displayName: 'Person Name',
            bottomPadding: 0,
            onSave: (_) {
              saveCalls++;
              return saving.future;
            },
          ),
          textScale: 3,
        ),
      );
      final edit = find.byKey(const Key('editProfileButton'));
      await tester.ensureVisible(edit);
      await tester.tap(edit);
      await tester.pumpAndSettle();
      final done = find.byKey(const Key('doneProfileEditButton'));
      await tester.ensureVisible(done);
      expect(tester.getSize(done).height, greaterThanOrEqualTo(44));
      await tester.tap(done);
      await tester.tap(done);
      await tester.pump();
      expect(saveCalls, 1);
      expect(find.text('Saving'), findsOneWidget);
      expect(tester.takeException(), isNull);
      saving.completeError(StateError('Offline. Your changes are preserved.'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('profileSaveError')), findsOneWidget);
      expect(find.byKey(const Key('doneProfileEditButton')), findsOneWidget);
      expect(find.byKey(const Key('cancelProfileEditButton')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'summary save errors keep the action available for a successful retry',
    (tester) async {
      var attempts = 0;
      await tester.pumpWidget(
        harness(
          WeeklyReportScreen(
            onSaveReport: (_) async {
              attempts++;
              if (attempts == 1) throw StateError('Offline');
              return 'report';
            },
          ),
        ),
      );
      final prepare = find.byKey(const Key('prepareSummaryButton'));
      await tester.scrollUntilVisible(
        prepare,
        300,
        scrollable: find.byType(Scrollable),
      );
      await tester.tap(prepare);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('prepareSummaryError')), findsOneWidget);
      expect(find.text('Prepared Summary'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(prepare);
      await tester.tap(prepare);
      await tester.pumpAndSettle();
      expect(attempts, 2);
      expect(find.text('Prepared Summary'), findsOneWidget);
    },
  );

  testWidgets(
    'summary preparation keeps its loading label and stable indicator key',
    (tester) async {
      final saving = Completer<String>();
      await tester.pumpWidget(
        harness(WeeklyReportScreen(onSaveReport: (_) => saving.future)),
      );
      final prepare = find.byKey(const Key('prepareSummaryButton'));
      await tester.scrollUntilVisible(
        prepare,
        300,
        scrollable: find.byType(Scrollable),
      );
      await tester.tap(prepare);
      await tester.pump();
      expect(
        find.byKey(const Key('prepareSummaryLoadingIndicator')),
        findsOneWidget,
      );
      expect(find.text('Preparing Summary'), findsOneWidget);
      saving.complete('report');
      await tester.pumpAndSettle();
      expect(find.text('Prepared Summary'), findsOneWidget);
    },
  );

  testWidgets(
    'failed summary copying leaves review content visible and permits retry',
    (tester) async {
      var attempts = 0;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData' && ++attempts == 1) {
            throw PlatformException(code: 'clipboard-unavailable');
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await tester.pumpWidget(harness(WeeklyReportScreen()));
      await tester.scrollUntilVisible(
        find.byKey(const Key('prepareSummaryButton')),
        300,
        scrollable: find.byType(Scrollable),
      );
      await tester.tap(find.byKey(const Key('prepareSummaryButton')));
      await tester.pumpAndSettle();
      final copy = find.byKey(const Key('copySummaryAgainButton'));
      await tester.tap(copy);
      await tester.pumpAndSettle();
      expect(
        find.text('Summary could not be copied. Try again.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('preparedSummaryText')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(copy);
      await tester.pumpAndSettle();
      expect(find.text('Summary copied'), findsOneWidget);
    },
  );

  testWidgets(
    'large-text privacy page fits its camera action on a narrow screen',
    (tester) async {
      narrowScreen(tester);
      await tester.pumpWidget(
        harness(
          SettingsScreen(
            appearanceMode: ThemeMode.system,
            onAppearanceModeChanged: (_) {},
            accentColor: AppAccentColor.blue,
            onAccentColorChanged: (_) {},
          ),
          textScale: 3,
        ),
      );
      final scrollable = find.descendant(
        of: find.byKey(const Key('settingsScrollView')),
        matching: find.byType(Scrollable),
      );
      await tester.scrollUntilVisible(
        find.text('Privacy Controls'),
        300,
        scrollable: scrollable,
      );
      await tester.ensureVisible(find.text('Privacy Controls'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Privacy Controls'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('privacyControlsPage')), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(const Key('cameraAccessControl')),
        200,
        scrollable: find
            .descendant(
              of: find.byKey(const Key('privacyControlsPage')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(find.byKey(const Key('cameraAccessControl')), findsOneWidget);
      expect(find.widgetWithText(AppButton, 'Allow'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('large-text prepared summary keeps both review actions usable', (
    tester,
  ) async {
    narrowScreen(tester);
    await tester.pumpWidget(harness(WeeklyReportScreen(), textScale: 3));
    await tester.scrollUntilVisible(
      find.byKey(const Key('prepareSummaryButton')),
      300,
      scrollable: find.byType(Scrollable),
    );
    await tester.ensureVisible(find.byKey(const Key('prepareSummaryButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('prepareSummaryButton')));
    await tester.pumpAndSettle();
    expect(find.text('Prepared Summary'), findsOneWidget);
    final done = find.byKey(const Key('closeSummaryButton'));
    await tester.scrollUntilVisible(
      done,
      200,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('preparedSummaryPage')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.ensureVisible(done);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('copySummaryAgainButton')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(done);
    await tester.pumpAndSettle();
    expect(find.text('Prepared Summary'), findsNothing);
  });
}
