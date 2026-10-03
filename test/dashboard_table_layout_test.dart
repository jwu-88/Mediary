import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediary/dashboard_screen.dart';

void main() {
  Future<void> pumpDashboardTable(
    WidgetTester tester, {
    required Size size,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DashboardScreen(
            email: 'person@example.com',
            displayName: 'Taylor Morgan',
            now: DateTime(2026, 8, 23, 9),
            bottomPadding: 24,
            initialDoses: const [
              DashboardDoseData(
                id: 'layout-dose',
                name: 'Ibuprofen 200 MG Oral Capsule',
                details: '200 MG · 09/27/2026 · 10:36 AM',
                status: 'due',
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final scrollable = find.descendant(
      of: find.byKey(const Key('dashboardScrollView')),
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(
      find.byKey(const Key('dashboardScheduleTable')),
      240,
      scrollable: scrollable,
    );
  }

  testWidgets('schedule table reserves artwork space and aligns columns', (
    tester,
  ) async {
    await pumpDashboardTable(tester, size: const Size(320, 800));

    expect(tester.takeException(), isNull);

    final artwork = tester.getRect(
      find.byKey(const Key('dashboardMedicationArtwork_layout-dose')),
    );
    final medicationCell = tester.getRect(
      find.byKey(const ValueKey('dashboardScheduleMedicationCell0')),
    );
    final doseCell = tester.getRect(
      find.byKey(const ValueKey('dashboardScheduleDoseCell0')),
    );
    final statusCell = tester.getRect(
      find.byKey(const ValueKey('dashboardScheduleStatusCell0')),
    );

    expect(medicationCell.left, greaterThanOrEqualTo(artwork.right + 8));
    expect(doseCell.right, lessThanOrEqualTo(statusCell.left));
    expect(statusCell.left, greaterThan(doseCell.left));

    for (var column = 0; column < 2; column++) {
      final headerX = tester
          .getCenter(
            find.byKey(Key('dashboardScheduleHeaderVerticalDivider$column')),
          )
          .dx;
      final rowX = tester
          .getCenter(
            find.byKey(
              Key('dashboardScheduleRowVerticalDivider0Column$column'),
            ),
          )
          .dx;
      expect(rowX, closeTo(headerX, .01));
    }

    expect(find.text('Medication'), findsOneWidget);
    expect(find.text('Dose & Time'), findsOneWidget);
    expect(find.text('Status'), findsOneWidget);

    final medicationHeaderCell = tester.getRect(
      find.byKey(const Key('dashboardScheduleMedicationHeaderCell')),
    );
    final doseHeaderCell = tester.getRect(
      find.byKey(const Key('dashboardScheduleDoseHeaderCell')),
    );
    final statusHeaderCell = tester.getRect(
      find.byKey(const Key('dashboardScheduleStatusHeaderCell')),
    );
    expect(
      tester.getRect(find.text('Medication')).top,
      medicationHeaderCell.top,
    );
    expect(tester.getRect(find.text('Dose & Time')).top, doseHeaderCell.top);
    expect(tester.getRect(find.text('Status')).top, statusHeaderCell.top);

    final medicationText = tester.widget<Text>(
      find.descendant(
        of: find.byKey(const ValueKey('dashboardScheduleMedicationCell0')),
        matching: find.byType(Text),
      ),
    );
    final doseText = tester.widget<Text>(
      find.descendant(
        of: find.byKey(const ValueKey('dashboardScheduleDoseCell0')),
        matching: find.byType(Text),
      ),
    );
    expect(medicationText.maxLines, 2);
    expect(medicationText.overflow, TextOverflow.ellipsis);
    expect(doseText.maxLines, 2);
    expect(doseText.overflow, TextOverflow.ellipsis);
    expect(find.text('200 MG\n09/27/2026 · 10:36 AM'), findsOneWidget);
  });

  testWidgets(
    'wide schedule table keeps artwork and headers on the same grid',
    (tester) async {
      await pumpDashboardTable(tester, size: const Size(585, 900));

      expect(tester.takeException(), isNull);
      final artwork = tester.getRect(
        find.byKey(const Key('dashboardMedicationArtwork_layout-dose')),
      );
      final medicationCell = tester.getRect(
        find.byKey(const ValueKey('dashboardScheduleMedicationCell0')),
      );
      expect(medicationCell.left, greaterThanOrEqualTo(artwork.right + 8));

      for (var column = 0; column < 2; column++) {
        final headerX = tester
            .getCenter(
              find.byKey(Key('dashboardScheduleHeaderVerticalDivider$column')),
            )
            .dx;
        final rowX = tester
            .getCenter(
              find.byKey(
                Key('dashboardScheduleRowVerticalDivider0Column$column'),
              ),
            )
            .dx;
        expect(rowX, closeTo(headerX, .01));
      }
    },
  );

  testWidgets('dashboard delete control removes a dose without opening it', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    String? changedDoseId;
    String? changedStatus;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DashboardScreen(
            email: 'person@example.com',
            displayName: 'Taylor Morgan',
            now: DateTime(2026, 8, 23, 9),
            bottomPadding: 24,
            initialDoses: const [
              DashboardDoseData(
                id: 'delete-dose',
                name: 'Ibuprofen 200 MG Oral Capsule',
                details: '200 MG · 10:36:00 AM',
                status: 'due',
              ),
            ],
            onDoseStatusChanged: (id, status, {snoozedUntil}) async {
              changedDoseId = id;
              changedStatus = status;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const Key('dashboardDeleteDose_delete-dose')),
      240,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('dashboardScrollView')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.ensureVisible(
      find.byKey(const Key('dashboardDeleteDose_delete-dose')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('dashboardDeleteDose_delete-dose')));
    await tester.pumpAndSettle();

    expect(changedDoseId, 'delete-dose');
    expect(changedStatus, 'cancelled');
    expect(find.text('Ibuprofen 200 MG Oral Capsule'), findsNothing);
    expect(find.text('Remove From Today'), findsNothing);
  });

  testWidgets('dashboard delete control removes the medication regimen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    String? removedMedicationId;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DashboardScreen(
            email: 'person@example.com',
            displayName: 'Taylor Morgan',
            now: DateTime(2026, 8, 23, 9),
            bottomPadding: 24,
            initialDoses: const [
              DashboardDoseData(
                id: 'delete-medication-morning',
                medicationId: 'medication-1',
                name: 'Ibuprofen',
                details: '200 MG · 8:00 AM',
                status: 'due',
              ),
              DashboardDoseData(
                id: 'delete-medication-evening',
                medicationId: 'medication-1',
                name: 'Ibuprofen',
                details: '200 MG · 8:00 PM',
                status: 'due',
              ),
            ],
            onRemoveMedication: (medicationId) async {
              removedMedicationId = medicationId;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const Key('dashboardDeleteDose_delete-medication-morning')),
      240,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('dashboardScrollView')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.ensureVisible(
      find.byKey(const Key('dashboardDeleteDose_delete-medication-morning')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('dashboardDeleteDose_delete-medication-morning')),
    );
    await tester.pumpAndSettle();

    expect(removedMedicationId, 'medication-1');
    expect(find.text('Ibuprofen'), findsNothing);
  });
}
