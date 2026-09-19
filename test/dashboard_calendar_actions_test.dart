import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediary/calendar_screen.dart';
import 'package:mediary/dashboard_screen.dart';

void main() {
  Finder dashboardRowDividers() => find.byWidgetPredicate(
    (widget) =>
        widget is Divider &&
        widget.key is ValueKey<String> &&
        (widget.key! as ValueKey<String>).value.startsWith(
          'dashboardScheduleRowDivider',
        ),
  );

  Finder dashboardVerticalDividers() => find.byWidgetPredicate(
    (widget) =>
        widget is VerticalDivider &&
        widget.key is ValueKey<String> &&
        (widget.key! as ValueKey<String>).value.contains(
          'ScheduleRowVerticalDivider',
        ),
  );

  void usePhoneSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('dashboard actions update the daily schedule', (tester) async {
    usePhoneSize(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DashboardScreen(
            email: 'person@example.com',
            displayName: 'Taylor Morgan',
            now: DateTime(2026, 8, 23),
            initialDoses: const [
              DashboardDoseData(
                id: 'dose-1',
                name: 'Vitamin D3',
                details: '1000 IU · 8:00 AM',
                status: 'taken',
              ),
              DashboardDoseData(
                id: 'dose-2',
                name: 'Amoxicillin',
                details: '500 mg · 10:30 AM',
                status: 'due',
              ),
              DashboardDoseData(
                id: 'dose-3',
                name: 'Cetirizine',
                details: '10 mg · 8:00 PM',
                status: 'due',
              ),
            ],
          ),
        ),
      ),
    );

    expect(
      find.byKey(const Key('dashboardScheduleHeaderDivider')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('dashboardMedicationArtwork_dose-1')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('dashboardMedicationArtwork_dose-2')),
      findsOneWidget,
    );
    expect(dashboardRowDividers(), findsNWidgets(2));
    expect(dashboardVerticalDividers(), findsNWidgets(6));
    for (var column = 0; column < 2; column++) {
      final headerX = tester
          .getCenter(
            find.byKey(Key('dashboardScheduleHeaderVerticalDivider$column')),
          )
          .dx;
      for (var row = 0; row < 3; row++) {
        final rowX = tester
            .getCenter(
              find.byKey(
                Key('dashboardScheduleRowVerticalDivider${row}Column$column'),
              ),
            )
            .dx;
        expect(rowX, closeTo(headerX, .01));
      }
    }
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('View Report'));
    await tester.pumpAndSettle();
    expect(find.text('Weekly Report'), findsOneWidget);

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('dashboardAddButton')), findsNothing);
    expect(find.byKey(const Key('dashboardCalendarGuidance')), findsOneWidget);

    await tester.tap(find.text('Amoxicillin'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mark As Taken'));
    await tester.pumpAndSettle();
    expect(find.text('Dose Taken'), findsOneWidget);
  });

  testWidgets('dashboard empty state offers an interactive calendar shortcut', (
    tester,
  ) async {
    usePhoneSize(tester);
    var calendarOpens = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DashboardScreen(
            email: 'person@example.com',
            now: DateTime(2026, 8, 23, 14),
            onOpenCalendar: () => calendarOpens++,
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('dashboardFocusCard')), findsOneWidget);
    expect(find.text('No Doses Scheduled'), findsOneWidget);
    expect(find.text('Make Today Easier'), findsNothing);
    expect(find.text('Good Afternoon, person'), findsOneWidget);
    expect(find.byKey(const Key('dashboardTodayMetric')), findsOneWidget);
    expect(find.byKey(const Key('dashboardWeekMetric')), findsOneWidget);
    final guidance = find.byKey(const Key('dashboardCalendarGuidance'));
    final emptySchedule = find.text('No medications scheduled');
    expect(guidance, findsOneWidget);
    expect(emptySchedule, findsOneWidget);
    expect(
      tester.getTopLeft(guidance).dy,
      lessThan(tester.getTopLeft(emptySchedule).dy),
    );
    await tester.ensureVisible(
      find.byKey(const Key('dashboardCalendarGuidanceButton')),
    );
    await tester.tap(find.byKey(const Key('dashboardCalendarGuidanceButton')));
    expect(calendarOpens, 1);
    await tester.tap(find.byKey(const Key('dashboardFocusActionButton')));
    expect(calendarOpens, 2);
  });

  testWidgets('calendar guidance stays usable on a narrow mobile viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DashboardScreen(
            email: 'person@example.com',
            now: DateTime(2026, 8, 23, 14),
            onOpenCalendar: () {},
          ),
        ),
      ),
    );

    expect(
      find.byKey(const Key('dashboardCalendarGuidanceButton')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('calendar controls and dose actions are interactive', (
    tester,
  ) async {
    usePhoneSize(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CalendarScreen(
            initialDate: DateTime(2026, 8, 23),
            initialDoses: const [
              CalendarDoseData(
                id: 'dose-1',
                localDate: '2026-08-23',
                name: 'Vitamin D3',
                details: '1000 IU · 8:00 AM',
                status: 'taken',
              ),
              CalendarDoseData(
                id: 'dose-2',
                localDate: '2026-08-23',
                name: 'Amoxicillin',
                details: '500 mg · 10:30 AM',
                status: 'due',
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('August 2026'), findsOneWidget);
    expect(find.text('Vitamin D3'), findsOneWidget);
    expect(find.text('Amoxicillin'), findsOneWidget);
    expect(
      find.byKey(const Key('calendarMedicationArtwork_dose-1')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('nextMonthButton')));
    await tester.pump();
    expect(find.text('September 2026'), findsOneWidget);
    expect(find.text('No medications scheduled'), findsOneWidget);
    expect(find.text('Vitamin D3'), findsNothing);
    expect(find.text('Amoxicillin'), findsNothing);

    await tester.tap(find.byKey(const Key('previousMonthButton')));
    await tester.pump();
    expect(find.text('August 2026'), findsOneWidget);
    expect(find.text('Vitamin D3'), findsOneWidget);
    expect(find.text('Amoxicillin'), findsOneWidget);

    await tester.tap(find.byKey(const Key('nextMonthButton')));
    await tester.pump();
    expect(find.text('September 2026'), findsOneWidget);
    expect(find.text('No medications scheduled'), findsOneWidget);

    await tester.tap(find.byKey(const Key('calendarAddButton')));
    await tester.pumpAndSettle();
    expect(
      find.text('Search the medication catalog to create a schedule.'),
      findsOneWidget,
    );
  });

  testWidgets('calendar renders a newly committed dose on its scheduled day', (
    tester,
  ) async {
    usePhoneSize(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CalendarScreen(
            initialDate: DateTime(2026, 8, 23),
            onAddDose: (date) async => [
              CalendarDoseData(
                id: 'dose-new',
                localDate:
                    '${date.year}-${date.month.toString().padLeft(2, '0')}-'
                    '${date.day.toString().padLeft(2, '0')}',
                name: 'Metformin',
                details: '500 mg · 08:00',
                status: 'due',
              ),
            ],
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('calendarAddButton')));
    await tester.pumpAndSettle();

    expect(find.text('Metformin'), findsOneWidget);
    expect(find.text('Metformin Scheduled'), findsOneWidget);
  });

  testWidgets('calendar removal cancels the dose and removes its row', (
    tester,
  ) async {
    usePhoneSize(tester);
    final statusChanges = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CalendarScreen(
            initialDate: DateTime(2026, 8, 23),
            initialDoses: const [
              CalendarDoseData(
                id: 'dose-remove',
                localDate: '2026-08-23',
                name: 'Metformin',
                details: '500 mg · 08:00',
                status: 'due',
              ),
            ],
            onDoseStatusChanged: (id, status) async {
              statusChanges.add('$id:$status');
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Metformin'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove From Day'));
    await tester.pumpAndSettle();

    expect(statusChanges, ['dose-remove:cancelled']);
    expect(find.text('Metformin'), findsNothing);
    expect(find.text('No medications scheduled'), findsOneWidget);
    expect(find.text('Metformin Removed'), findsOneWidget);
  });
}
