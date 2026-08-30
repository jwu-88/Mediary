import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediary/add_medication_screen.dart';

void main() {
  void usePhoneSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('filters medications by name and generic name', (tester) async {
    usePhoneSize(tester);
    await tester.pumpWidget(const MaterialApp(home: AddMedicationScreen()));

    expect(find.text('Amoxicillin'), findsOneWidget);
    expect(find.text('Vitamin D3'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('medicationSearchField')),
      'cholecalciferol',
    );
    await tester.pump();

    expect(find.text('Vitamin D3'), findsOneWidget);
    expect(find.text('Amoxicillin'), findsNothing);

    await tester.enterText(
      find.byKey(const Key('medicationSearchField')),
      'not a medicine',
    );
    await tester.pump();
    expect(find.text('No Medications Found'), findsOneWidget);

    await tester.tap(find.text('Clear Search'));
    await tester.pump();
    expect(find.text('Amoxicillin'), findsOneWidget);
  });

  testWidgets('returns selected medication records in catalog order', (
    tester,
  ) async {
    usePhoneSize(tester);
    List<MedicationOption>? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await showAddMedicationScreen(context);
            },
            child: const Text('Open Picker'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open Picker'));
    await tester.pumpAndSettle();
    expect(find.text('Add Medication'), findsOneWidget);

    await tester.tap(
      find.byKey(const Key('medicationOption_ibuprofen-200-tablet')),
    );
    await tester.tap(
      find.byKey(const Key('medicationOption_amoxicillin-500-capsule')),
    );
    await tester.pump();

    expect(find.text('2 Selected'), findsOneWidget);
    expect(find.text('Add Selected (2)'), findsOneWidget);
    await tester.tap(find.byKey(const Key('addSelectedMedicationsButton')));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(
      result!.map((medication) => medication.name),
      orderedEquals(['Amoxicillin', 'Ibuprofen']),
    );
  });

  testWidgets('cancel closes the picker with no result', (tester) async {
    usePhoneSize(tester);
    List<MedicationOption>? result = const <MedicationOption>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await showAddMedicationScreen(context);
            },
            child: const Text('Open Picker'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open Picker'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('cancelAddMedicationButton')));
    await tester.pumpAndSettle();

    expect(result, isNull);
    expect(find.text('Open Picker'), findsOneWidget);
  });

  testWidgets('uses the local image fallback when a remote image fails', (
    tester,
  ) async {
    usePhoneSize(tester);
    const unavailableMedication = MedicationOption(
      id: 'unavailable',
      name: 'Sample Medication',
      genericName: 'Sample Generic',
      strength: '25 mg',
      form: 'Tablet',
      imageUrl: 'invalid://medication-image',
      fallbackColor: Color(0xFFE2E9DF),
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: AddMedicationScreen(medications: [unavailableMedication]),
      ),
    );
    await tester.pump();

    expect(find.byIcon(Icons.error), findsNothing);
    expect(find.byIcon(CupertinoIcons.capsule_fill), findsOneWidget);
  });
}
