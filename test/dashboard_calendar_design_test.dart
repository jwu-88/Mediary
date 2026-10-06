import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediary/app_theme.dart';
import 'package:mediary/calendar_screen.dart';
import 'package:mediary/dashboard_screen.dart';

void main() {
  Future<void> reach(
    WidgetTester tester,
    String page,
    Finder target, {
    bool reverse = false,
  }) async {
    await tester.scrollUntilVisible(
      target,
      reverse ? -180 : 180,
      scrollable: find
          .descendant(
            of: find.byKey(Key('${page}ScrollView')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
  }

  for (final scenario in [
    (const Size(320, 640), 1.0),
    (const Size(320, 640), 3.0),
    (const Size(430, 932), 1.0),
    (const Size(1280, 900), 2.0),
  ]) {
    for (final page in ['dashboard', 'calendar']) {
      testWidgets(
        '$page actions remain usable at ${scenario.$1} with ${scenario.$2}x text',
        (tester) async {
          tester.view.physicalSize = scenario.$1;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final pendingAdd = Completer<List<CalendarDoseData>?>();
          var addCalls = 0;
          var reportCalls = 0;
          var calendarCalls = 0;
          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.light,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scenario.$2)),
                child: child!,
              ),
              home: Scaffold(
                body: page == 'dashboard'
                    ? DashboardScreen(
                        email: 'alex@example.com',
                        now: DateTime(2026, 8, 23, 14),
                        onViewReport: () => reportCalls++,
                        onOpenCalendar: () => calendarCalls++,
                      )
                    : CalendarScreen(
                        initialDate: DateTime(2026, 8, 23),
                        onAddDose: (_) {
                          addCalls++;
                          return pendingAdd.future;
                        },
                      ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          if (page == 'dashboard') {
            final report = find.byKey(const Key('dashboardViewReportButton'));
            await reach(tester, page, report);
            expect(tester.getSize(report).height, greaterThanOrEqualTo(44));
            await tester.tap(report);
            await tester.tap(report);
            await tester.pump(const Duration(milliseconds: 450));
            expect(reportCalls, 1);
            final calendar = find.byKey(
              const Key('dashboardCalendarGuidanceButton'),
            );
            await reach(tester, page, calendar);
            await tester.tap(calendar);
            expect(calendarCalls, 1);
          } else {
            final next = find.byKey(const Key('nextMonthButton'));
            await reach(tester, page, next);
            expect(tester.getSize(next), const Size(44, 44));
            await tester.tap(next);
            await tester.pumpAndSettle();
            expect(find.text('September 2026'), findsOneWidget);
            final add = find.byKey(const Key('calendarAddButton'));
            await reach(tester, page, add);
            expect(tester.getSize(add).height, greaterThanOrEqualTo(44));
            await tester.tap(add);
            await tester.tap(add);
            await tester.pump();
            expect(addCalls, 1);
            expect(find.text('Add Medication'), findsOneWidget);
            expect(
              find.byKey(const Key('appButtonLoadingIndicator')),
              findsOneWidget,
            );
            pendingAdd.complete(null);
            await tester.pumpAndSettle();
            expect(
              find.byKey(const Key('appButtonLoadingIndicator')),
              findsNothing,
            );
            await tester.tap(add);
            await tester.pumpAndSettle();
            expect(addCalls, 2);
          }
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }
}
