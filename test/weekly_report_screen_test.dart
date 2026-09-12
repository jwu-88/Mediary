import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediary/app_theme.dart';
import 'package:mediary/weekly_report_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildReport({Widget? home}) {
    return MaterialApp(
      theme: AppTheme.light,
      home:
          home ??
          WeeklyReportScreen(
            weekEnding: DateTime(2026, 8, 30),
            dailyTaken: const [2, 2, 2, 1, 2, 1, 1],
            dailyScheduled: const [2, 2, 2, 2, 2, 1, 1],
            timingOffsetsMinutes: const [2, -1, 5, 12, 4, 8, 9],
          ),
    );
  }

  testWidgets('shows adherence and two weekly charts', (tester) async {
    await tester.pumpWidget(buildReport());

    expect(find.text('Weekly Report'), findsOneWidget);
    expect(find.text('Week Ending August 30, 2026'), findsOneWidget);
    expect(find.text('92%'), findsOneWidget);
    expect(find.text('11 of 12'), findsOneWidget);
    expect(find.byKey(const Key('adherenceChart')), findsOneWidget);
    expect(find.byKey(const Key('dailyDoseChart')), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byKey(const Key('doseTimingChart')),
      300,
      scrollable: find.byType(Scrollable),
    );
    expect(find.byKey(const Key('doseTimingChart')), findsOneWidget);
  });

  testWidgets('daily dose chart exposes each stacked column as text', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      buildReport(
        home: WeeklyReportScreen(
          weekEnding: DateTime(2026, 8, 30),
          dailyTaken: const [2, 2, 2, 1, 2, 1, 1],
          dailyScheduled: const [2, 2, 2, 2, 2, 1, 1],
        ),
      ),
    );

    final chartSemantics = tester.getSemantics(
      find.byKey(const Key('dailyDoseChartSemantics')),
    );
    expect(chartSemantics.label, contains('Monday: 2 of 2 taken'));
    expect(chartSemantics.label, contains('Thursday: 1 of 2 taken'));
    expect(chartSemantics.label, contains('Sunday: 1 of 1 taken'));
    semantics.dispose();
  });

  testWidgets('normalizes incomplete and invalid external report data', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildReport(
        home: WeeklyReportScreen(
          weekEnding: DateTime(2026, 8, 30),
          dailyTaken: const [4, -1],
          dailyScheduled: const [2],
          timingOffsetsMinutes: const [],
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('100%'), findsOneWidget);
    expect(find.text('2 of 2'), findsOneWidget);
    expect(find.byKey(const Key('dailyDoseChart')), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byKey(const Key('doseTimingChart')),
      300,
      scrollable: find.byType(Scrollable),
    );
    expect(find.byKey(const Key('doseTimingChart')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('prepares a weekly summary and copies only on request', (
    tester,
  ) async {
    MethodCall? clipboardCall;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') clipboardCall = call;
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await tester.pumpWidget(buildReport());
    await tester.scrollUntilVisible(
      find.byKey(const Key('prepareSummaryButton')),
      400,
      scrollable: find.byType(Scrollable),
    );
    await tester.tap(find.byKey(const Key('prepareSummaryButton')));
    await tester.pumpAndSettle();

    expect(find.text('Prepared Summary'), findsOneWidget);
    expect(find.text('Ready to review and copy'), findsOneWidget);
    expect(find.byKey(const Key('preparedSummaryText')), findsOneWidget);
    expect(clipboardCall, isNull);

    await tester.tap(find.byKey(const Key('copySummaryAgainButton')));
    await tester.pumpAndSettle();
    expect(find.text('Summary copied'), findsOneWidget);
    expect(clipboardCall?.method, 'Clipboard.setData');
    final arguments = clipboardCall?.arguments as Map<Object?, Object?>?;
    expect(arguments?['text'], contains('92% adherence'));
    expect(arguments?['text'], contains('11 of 12 scheduled doses'));

    await tester.tap(find.byKey(const Key('copySummaryAgainButton')));
    await tester.pumpAndSettle();
    expect(find.text('Summary copied'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);

    await tester.tap(find.byKey(const Key('closeSummaryButton')));
    await tester.pumpAndSettle();
    expect(find.text('Prepared Summary'), findsNothing);
  });

  testWidgets('back control returns to the previous page', (tester) async {
    await tester.pumpWidget(
      buildReport(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              key: const Key('openReportButton'),
              onPressed: () => Navigator.push<void>(
                context,
                MaterialPageRoute<void>(
                  builder: (_) =>
                      WeeklyReportScreen(weekEnding: DateTime(2026, 8, 30)),
                ),
              ),
              child: const Text('Open Report'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('openReportButton')));
    await tester.pumpAndSettle();
    expect(find.text('Weekly Report'), findsOneWidget);

    await tester.tap(find.byKey(const Key('weeklyReportBackButton')));
    await tester.pumpAndSettle();
    expect(find.text('Open Report'), findsOneWidget);
    expect(find.text('Weekly Report'), findsNothing);
  });
}
