import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediary/calendar_screen.dart';

void main() {
  void usePhoneSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('calendar dose table keeps artwork separate from long names', (
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
                id: 'long-dose',
                localDate: '2026-08-23',
                name: 'Ibuprofen 200 MG Oral Capsule Extended Release',
                details: '200 MG · 10:36:00 AM',
                status: 'due',
              ),
            ],
          ),
        ),
      ),
    );

    final artwork = tester.getRect(
      find.byKey(const Key('calendarMedicationArtwork_long-dose')),
    );
    final name = tester.getRect(
      find.byKey(const Key('calendarMedicationName_long-dose')),
    );
    expect(artwork.right, lessThanOrEqualTo(name.left));

    final headerDivider = tester.getCenter(
      find.byKey(const Key('calendarDoseTableHeaderVerticalDivider0')),
    );
    final rowDivider = tester.getCenter(
      find.byKey(const Key('calendarDoseTableRowVerticalDividerlong-dose0')),
    );
    expect(rowDivider.dx, closeTo(headerDivider.dx, .01));

    final nameText = tester.widget<Text>(
      find.byKey(const Key('calendarMedicationName_long-dose')),
    );
    final detailsText = tester.widget<Text>(
      find.byKey(const Key('calendarDoseDetails_long-dose')),
    );
    final statusText = tester.widget<Text>(
      find.byKey(const Key('calendarDoseStatus_long-dose')),
    );
    expect(nameText.maxLines, 2);
    expect(nameText.overflow, TextOverflow.ellipsis);
    expect(detailsText.maxLines, 2);
    expect(detailsText.overflow, TextOverflow.ellipsis);
    expect(statusText.maxLines, 1);
    expect(statusText.overflow, TextOverflow.ellipsis);
    expect(tester.takeException(), isNull);
  });

  testWidgets('calendar dose table headers use consistent column labels', (
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
            ],
          ),
        ),
      ),
    );

    expect(find.text('Medication'), findsOneWidget);
    expect(find.text('Dose & Time'), findsOneWidget);
    expect(find.text('Status'), findsOneWidget);
    expect(find.byKey(const Key('calendarDoseTable')), findsOneWidget);
    expect(
      find.byKey(const Key('calendarDoseTableHeaderVerticalDivider0')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('calendarDoseTableHeaderVerticalDivider1')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('calendar delete control removes a dose without opening it', (
    tester,
  ) async {
    usePhoneSize(tester);
    String? changedDoseId;
    String? changedStatus;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CalendarScreen(
            initialDate: DateTime(2026, 8, 23),
            initialDoses: const [
              CalendarDoseData(
                id: 'delete-dose',
                localDate: '2026-08-23',
                name: 'Vitamin D3',
                details: '1000 IU · 8:00 AM',
                status: 'due',
              ),
            ],
            onDoseStatusChanged: (id, status) async {
              changedDoseId = id;
              changedStatus = status;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const Key('calendarDeleteDose_delete-dose')),
      240,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('calendarScrollView')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(find.byKey(const Key('calendarDeleteDose_delete-dose')));
    await tester.pumpAndSettle();

    expect(changedDoseId, 'delete-dose');
    expect(changedStatus, 'cancelled');
    expect(find.text('Vitamin D3'), findsNothing);
    expect(find.text('Remove From Day'), findsNothing);
  });
}
