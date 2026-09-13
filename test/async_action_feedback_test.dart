import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediary/app_theme.dart';
import 'package:mediary/dashboard_screen.dart';
import 'package:mediary/settings_screen.dart';
import 'package:mediary/weekly_report_screen.dart';

void main() {
  void usePhoneSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('dashboard directs medication changes to the Calendar', (
    tester,
  ) async {
    usePhoneSize(tester);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DashboardScreen(
            email: 'person@example.com',
            now: DateTime(2026, 8, 30),
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('dashboardAddButton')), findsNothing);
    expect(find.byKey(const Key('dashboardCalendarGuidance')), findsOneWidget);
    expect(
      find.text('To add or manage medications, go to the Calendar page.'),
      findsOneWidget,
    );
  });

  testWidgets('dashboard report action cannot push twice during transition', (
    tester,
  ) async {
    usePhoneSize(tester);
    var openCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: DashboardScreen(
          email: 'person@example.com',
          now: DateTime(2026, 8, 30),
          onViewReport: () => openCalls += 1,
        ),
      ),
    );

    final reportButton = find.byKey(const Key('dashboardViewReportButton'));
    await tester.tap(reportButton);
    await tester.tap(reportButton);
    await tester.pump();

    expect(openCalls, 1);
    expect(
      find.byKey(const Key('dashboardViewReportLoadingIndicator')),
      findsOneWidget,
    );

    await tester.pump(const Duration(milliseconds: 450));
    expect(
      find.byKey(const Key('dashboardViewReportLoadingIndicator')),
      findsNothing,
    );
  });

  testWidgets('weekly summary opens once without copying private data', (
    tester,
  ) async {
    usePhoneSize(tester);
    var clipboardCalls = 0;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) {
        if (call.method == 'Clipboard.setData') {
          clipboardCalls += 1;
        }
        return Future<Object?>.value();
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: WeeklyReportScreen(weekEnding: DateTime(2026, 8, 30)),
      ),
    );
    final button = find.byKey(const Key('prepareSummaryButton'));
    await tester.scrollUntilVisible(
      button,
      400,
      scrollable: find.byType(Scrollable),
    );
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();

    expect(find.text('Prepared Summary'), findsOneWidget);
    expect(clipboardCalls, 0);
  });

  testWidgets('data export reports progress and ignores repeat taps', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 1500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final clipboard = Completer<Object?>();
    var clipboardCalls = 0;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) {
        if (call.method == 'Clipboard.setData') {
          clipboardCalls += 1;
          return clipboard.future;
        }
        return Future<Object?>.value();
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: SettingsScreen(
          embedded: true,
          appearanceMode: ThemeMode.system,
          onAppearanceModeChanged: (_) {},
          accentColor: AppAccentColor.blue,
          onAccentColorChanged: (_) {},
          accountEmail: 'person@example.com',
        ),
      ),
    );
    final exportButton = find.byKey(const Key('exportDataButton'));
    await tester.scrollUntilVisible(
      exportButton,
      400,
      scrollable: find.byType(Scrollable),
    );
    await tester.tap(exportButton);
    await tester.tap(exportButton);
    await tester.pump();

    expect(clipboardCalls, 1);
    expect(find.byKey(const Key('exportDataLoadingIndicator')), findsOneWidget);

    clipboard.complete(null);
    await tester.pumpAndSettle();
    expect(find.text('Copied to device clipboard'), findsOneWidget);
    expect(find.byKey(const Key('exportDataLoadingIndicator')), findsNothing);
  });
}
