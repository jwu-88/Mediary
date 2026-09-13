import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediary/add_medication_screen.dart';

void main() {
  const fixtureMedications = [
    MedicationOption(
      id: 'amoxicillin-500-capsule',
      name: 'Amoxicillin',
      genericName: 'amoxicillin',
      strength: '500 mg',
      form: 'Capsule',
    ),
    MedicationOption(
      id: 'vitamin-d3-1000-iu',
      name: 'Vitamin D3',
      genericName: 'cholecalciferol',
      strength: '1000 IU',
      form: 'Tablet',
    ),
    MedicationOption(
      id: 'ibuprofen-200-tablet',
      name: 'Ibuprofen',
      genericName: 'ibuprofen',
      strength: '200 mg',
      form: 'Tablet',
    ),
  ];
  void usePhoneSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('filters medications by name and generic name', (tester) async {
    usePhoneSize(tester);
    await tester.pumpWidget(
      const MaterialApp(
        home: AddMedicationScreen(medications: fixtureMedications),
      ),
    );

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
              result = await showAddMedicationScreen(
                context,
                medications: fixtureMedications,
              );
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
    expect(
      find.byKey(const Key('selectedMedicationArtwork_ibuprofen-200-tablet')),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const Key('selectedMedicationArtwork_amoxicillin-500-capsule'),
      ),
      findsOneWidget,
    );
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

  testWidgets('does not render fabricated medication artwork', (tester) async {
    usePhoneSize(tester);
    const medication = MedicationOption(
      id: 'unavailable',
      name: 'Sample Medication',
      genericName: 'Sample Generic',
      strength: '25 mg',
      form: 'Tablet',
    );

    await tester.pumpWidget(
      const MaterialApp(home: AddMedicationScreen(medications: [medication])),
    );
    await tester.pump();

    expect(find.text('Sample Medication'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('uses readable title casing and larger medication rows', (
    tester,
  ) async {
    usePhoneSize(tester);
    const medication = MedicationOption(
      id: 'advil',
      name: 'ADVIL',
      genericName: 'ibuprofen',
      strength: '200 MG',
      form: 'oral tablet',
    );

    await tester.pumpWidget(
      const MaterialApp(home: AddMedicationScreen(medications: [medication])),
    );
    await tester.pump();

    expect(find.text('Advil'), findsOneWidget);
    expect(find.text('Ibuprofen · 200 MG · Oral Tablet'), findsOneWidget);
    expect(find.byKey(const Key('medicationArtwork_advil')), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const Key('medicationOption_advil'))).height,
      92,
    );
  });
}
