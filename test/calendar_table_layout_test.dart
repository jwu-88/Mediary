import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediary/calendar_screen.dart';

void main() {
  for (final size in const [
    Size(1024, 768),
    Size(1440, 900),
    Size(1920, 1080),
    Size(900, 600),
  ]) {
    for (final textScale in [1.0, 2.0]) {
      testWidgets(
        'calendar table stays readable at $size with ${textScale}x text',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          DateTime? addedDate;
          await tester.pumpWidget(
            MaterialApp(
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(textScale)),
                child: child!,
              ),
              home: Scaffold(
                // Match the desktop shell's reserved sidebar space without
                // changing the viewport MediaQuery seen by destination pages.
                body: Padding(
                  padding: const EdgeInsets.only(left: 76),
                  child: CalendarScreen(
                    initialDate: DateTime(2026, 9, 23),
                    bottomPadding: 24,
                    onAddDose: (date) async {
                      addedDate = date;
                      return null;
                    },
                    initialDoses: const [
                      CalendarDoseData(
                        id: 'desktop-dose',
                        localDate: '2026-09-23',
                        name: 'Amoxicillin Clavulanate Extended Release Tablet',
                        details: '875 MG / 125 MG · 10:36 AM',
                        status: 'taken',
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(
            find.byKey(const Key('calendarLandscapeContent')),
            textScale == 1 && size.width >= 1440
                ? findsOneWidget
                : findsNothing,
          );
          await tester.scrollUntilVisible(
            find.byKey(const Key('calendarDoseTable')),
            200,
            scrollable: find
                .descendant(
                  of: find.byKey(const Key('calendarScrollView')),
                  matching: find.byType(Scrollable),
                )
                .first,
          );
          await tester.pumpAndSettle();
          for (final key in [
            'calendarDoseTableMedicationHeader',
            'calendarDoseTableDoseHeader',
            'calendarDoseTableStatusHeader',
            'calendarDoseStatus_desktop-dose',
          ]) {
            final paragraph = tester.renderObject<RenderParagraph>(
              find.byKey(Key(key)),
            );
            expect(paragraph.didExceedMaxLines, isFalse, reason: key);
          }
          final artwork = tester.getRect(
            find.byKey(const Key('calendarMedicationArtwork_desktop-dose')),
          );
          final name = tester.getRect(
            find.byKey(const Key('calendarMedicationName_desktop-dose')),
          );
          expect(artwork.right, lessThanOrEqualTo(name.left));
          for (var column = 0; column < 2; column++) {
            expect(
              tester
                  .getCenter(
                    find.byKey(
                      Key(
                        'calendarDoseTableRowVerticalDividerdesktop-dose$column',
                      ),
                    ),
                  )
                  .dx,
              closeTo(
                tester
                    .getCenter(
                      find.byKey(
                        Key('calendarDoseTableHeaderVerticalDivider$column'),
                      ),
                    )
                    .dx,
                .01,
              ),
            );
          }
          await tester.ensureVisible(
            find.byKey(const Key('calendarDeleteDose_desktop-dose')),
          );
          await tester.pumpAndSettle();
          expect(
            find
                .byKey(const Key('calendarDeleteDose_desktop-dose'))
                .hitTestable(),
            findsOneWidget,
          );
          final scrollable = find
              .descendant(
                of: find.byKey(const Key('calendarScrollView')),
                matching: find.byType(Scrollable),
              )
              .first;
          await tester.scrollUntilVisible(
            find.byKey(const Key('nextMonthButton')),
            -200,
            scrollable: scrollable,
          );
          await tester.pumpAndSettle();
          await tester.ensureVisible(find.byKey(const Key('nextMonthButton')));
          await tester.pumpAndSettle();
          expect(
            find.byKey(const Key('nextMonthButton')).hitTestable(),
            findsOneWidget,
          );
          await tester.tap(find.byKey(const Key('nextMonthButton')));
          await tester.pumpAndSettle();
          expect(find.text('October 2026'), findsOneWidget);
          await tester.tap(find.byKey(const Key('previousMonthButton')));
          await tester.pumpAndSettle();
          expect(find.text('September 2026'), findsOneWidget);
          final nextDay = find.byKey(const Key('calendarDay-2026-09-24'));
          await tester.scrollUntilVisible(nextDay, 200, scrollable: scrollable);
          await tester.pumpAndSettle();
          await tester.tap(nextDay);
          await tester.pumpAndSettle();
          final add = find.byKey(const Key('calendarAddButton'));
          await tester.scrollUntilVisible(add, 200, scrollable: scrollable);
          await tester.pumpAndSettle();
          await tester.tap(add);
          await tester.pumpAndSettle();
          expect(addedDate, DateTime(2026, 9, 24));
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

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
