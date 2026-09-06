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
          ),
        ),
      ),
    );

    expect(
      find.byKey(const Key('dashboardScheduleHeaderDivider')),
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
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ibuprofen'));
    await tester.pumpAndSettle();
    expect(find.text('Ibuprofen'), findsOneWidget);
    expect(dashboardRowDividers(), findsNWidgets(3));
    expect(dashboardVerticalDividers(), findsNWidgets(8));

    await tester.tap(find.text('Amoxicillin'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mark As Taken'));
    await tester.pumpAndSettle();
    expect(find.text('Dose Taken'), findsOneWidget);
  });

  testWidgets('calendar controls and dose actions are interactive', (
    tester,
  ) async {
    usePhoneSize(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CalendarScreen(initialDate: DateTime(2026, 8, 23)),
        ),
      ),
    );

    expect(find.text('August 2026'), findsOneWidget);
    expect(find.text('Vitamin D3'), findsOneWidget);
    expect(find.text('Amoxicillin'), findsOneWidget);

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
    await tester.tap(find.text('Cetirizine'));
    await tester.pumpAndSettle();
    expect(find.text('Cetirizine'), findsOneWidget);

    await tester.tap(find.text('Cetirizine'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mark As Taken'));
    await tester.pumpAndSettle();
    expect(find.text('Dose Taken'), findsOneWidget);
  });
}
