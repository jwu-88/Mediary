import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediary/add_medication_screen.dart';

void main() {
  final medications = List.generate(
    12,
    (index) => MedicationOption(
      id: 'desktop-audit-$index',
      name: 'Amoxicillin Clavulanate Extended Release Medication $index',
      genericName: 'Amoxicillin And Clavulanate Potassium',
      strength: '875 MG / 125 MG',
      form: 'Extended Release Oral Tablet',
    ),
  );

  for (final size in const [
    Size(1024, 768),
    Size(1440, 900),
    Size(1920, 1080),
    Size(900, 600),
  ]) {
    testWidgets('selected medications remain usable at $size with large text', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: AddMedicationScreen(
            medications: medications,
            initiallySelectedIds: medications.map((item) => item.id).toSet(),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byKey(const Key('medicationOptionsList'))).height,
        greaterThanOrEqualTo(92),
      );
      await tester.ensureVisible(
        find.byKey(const Key('selectedMedicationChip_desktop-audit-11')),
      );
      await tester.pumpAndSettle();
      final lastChip = find.byKey(
        const Key('selectedMedicationChip_desktop-audit-11'),
      );
      expect(lastChip.hitTestable(), findsOneWidget);
      await tester.tap(
        find.descendant(of: lastChip, matching: find.byIcon(Icons.close)),
      );
      await tester.pumpAndSettle();
      expect(find.text('11 Selected'), findsOneWidget);
      await tester.tap(find.byKey(const Key('clearMedicationSelectionButton')));
      await tester.pumpAndSettle();
      expect(find.text('Select Items'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(const Key('medicationOption_desktop-audit-11')),
        200,
        scrollable: find.descendant(
          of: find.byKey(const Key('medicationOptionsList')),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const Key('medicationOption_desktop-audit-11')),
      );
      await tester.pumpAndSettle();
      expect(
        find
            .byKey(const Key('medicationOption_desktop-audit-11'))
            .hitTestable(),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const Key('medicationOption_desktop-audit-11')),
      );
      await tester.pumpAndSettle();
      expect(find.text('1 Selected'), findsOneWidget);
      expect(
        find.byKey(const Key('addSelectedMedicationsButton')).hitTestable(),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
