import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediary/dashboard_screen.dart';

void main() {
  testWidgets('one-click deletion removes only the selected medication', (
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
                id: 'delete-selected',
                medicationId: 'medication-1',
                name: 'Ibuprofen',
                details: '200 MG · 8:00 AM',
                status: 'due',
              ),
              DashboardDoseData(
                id: 'keep-neighbor',
                medicationId: 'medication-2',
                name: 'Lisinopril',
                details: '10 MG · 9:00 AM',
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

    final deleteButton = find.byKey(
      const Key('dashboardDeleteDose_delete-selected'),
    );
    await tester.scrollUntilVisible(
      deleteButton,
      240,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('dashboardScrollView')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.ensureVisible(deleteButton);
    await tester.pumpAndSettle();
    await tester.tap(deleteButton);
    await tester.pumpAndSettle();

    expect(removedMedicationId, 'medication-1');
    expect(find.text('Ibuprofen'), findsNothing);
    expect(find.text('Lisinopril'), findsOneWidget);
  });
}
