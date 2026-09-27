import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediary/calendar_screen.dart';

void main() {
  const dose = CalendarDoseData(
    id: 'dose-advil',
    localDate: '2026-09-27',
    name: 'advil',
    details: '200 MG · 10:36:00',
    status: 'due',
  );

  Widget harness({required ValueChanged<String> onStatusChanged}) {
    var page = 'calendar';
    var status = 'due';

    return MaterialApp(
      home: StatefulBuilder(
        builder: (context, setState) {
          final visibleDoses = status == 'cancelled'
              ? const <CalendarDoseData>[]
              : [dose];
          return Scaffold(
            appBar: AppBar(
              actions: [
                TextButton(
                  key: const Key('qaSwitchPageButton'),
                  onPressed: () => setState(
                    () => page = page == 'calendar' ? 'other' : 'calendar',
                  ),
                  child: Text(page == 'calendar' ? 'Other Page' : 'Calendar'),
                ),
              ],
            ),
            body: page == 'calendar'
                ? CalendarScreen(
                    initialDate: DateTime(2026, 9, 27),
                    initialDoses: visibleDoses,
                    onDoseStatusChanged: (id, nextStatus) async {
                      status = nextStatus;
                      onStatusChanged(nextStatus);
                      setState(() {});
                    },
                  )
                : const Center(child: Text('Other Page')),
          );
        },
      ),
    );
  }

  Finder calendarScrollable() => find
      .descendant(
        of: find.byKey(const Key('calendarScrollView')),
        matching: find.byType(Scrollable),
      )
      .first;

  testWidgets('scheduled dose survives calendar reconstruction', (
    tester,
  ) async {
    await tester.pumpWidget(harness(onStatusChanged: (_) {}));
    expect(find.text('Sunday, September 27'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Advil'),
      250,
      scrollable: calendarScrollable(),
    );
    expect(find.text('Advil'), findsOneWidget);
    expect(find.text('200 MG\n10:36:00'), findsOneWidget);

    await tester.tap(find.byKey(const Key('qaSwitchPageButton')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('qaSwitchPageButton')));
    await tester.pump();

    await tester.scrollUntilVisible(
      find.text('Advil'),
      250,
      scrollable: calendarScrollable(),
    );
    expect(find.text('Sunday, September 27'), findsOneWidget);
    expect(find.text('Advil'), findsOneWidget);
    expect(find.text('200 MG\n10:36:00'), findsOneWidget);
  });

  testWidgets('cancelled dose stays gone after navigation', (tester) async {
    String? changedStatus;
    await tester.pumpWidget(
      harness(onStatusChanged: (status) => changedStatus = status),
    );
    await tester.scrollUntilVisible(
      find.text('Advil'),
      250,
      scrollable: calendarScrollable(),
    );

    await tester.tap(find.text('Advil'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove From Day'));
    await tester.pumpAndSettle();
    expect(changedStatus, 'cancelled');
    expect(find.text('Advil'), findsNothing);

    await tester.tap(find.byKey(const Key('qaSwitchPageButton')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('qaSwitchPageButton')));
    await tester.pump();
    expect(find.text('Advil'), findsNothing);
  });
}
