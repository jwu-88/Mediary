import 'package:flutter_test/flutter_test.dart';
import 'package:mediary/data/medication_catalog_client.dart';
import 'package:mediary/medication_label_details.dart';
import 'package:mediary/medication_scan.dart';

const _tablet = MedicationCatalogRecord(
  rxcui: '153010',
  name: 'Ibuprofen 200 MG Oral Tablet [Advil]',
  genericName: 'ibuprofen',
  strength: '200 mg',
  form: 'oral tablet',
);

void main() {
  test('repeated noisy Advil readings become unique literal facts', () {
    final details = MedicationLabelDetails.fromText('''Advil
buprofen Tablets, 200mg__ .
Pain Reliever/ Fever Reducer (NSap)
Drug Fac
Ibuprofen Tablets, 200 mg .
Active ing ent (in each tablet | '1Y
Ibuprofen Tablets, 200 mg
Drug Facts
Active ingredient (in each tablet)
Ibuprofen 200 mg
Uses
pain reliever / fever reducer''');
    expect(details.ingredients, ['Ibuprofen']);
    expect(details.strengths, ['200 mg']);
    expect(details.forms, ['Tablet']);
    expect(details.conflictsWith(_tablet), isFalse);
  });

  test('warning and instruction drug names never become product facts', () {
    for (final text in [
      'Ibuprofen 200mg tablets\nWarnings\nAspirin 325mg capsule\nInactive ingredients\nAcetaminophen 500mg',
      'Ibuprofen 200mg tablets. Do not take aspirin 325mg capsules.',
      'Ibuprofen 200mg tablets\nDirections\nTake acetaminophen 500mg',
      'Ibuprofen 200mg tablets\nCompare to aspirin 325mg capsules',
    ]) {
      final details = MedicationLabelDetails.fromText(text);
      expect(details.ingredients, ['Ibuprofen'], reason: text);
      expect(details.strengths, ['200 mg'], reason: text);
      expect(details.forms, ['Tablet'], reason: text);
    }
  });

  test(
    'a later active ingredient section can supply readable product facts',
    () {
      final details = MedicationLabelDetails.fromText(
        'Advil\nUses\nPain reliever\nDrug Facts\nActive ingredient\nIbuprofen 200 mg tablets',
      );
      expect(details.ingredients, ['Ibuprofen']);
      expect(details.strengths, ['200 mg']);
      expect(details.forms, ['Tablet']);
    },
  );

  test('brand names and corrupt ingredient strings never invent facts', () {
    for (final text in ['Advil', 'Benadry!\nD|ph(=nhydramme', 'Qzxv!!!', '']) {
      final details = MedicationLabelDetails.fromText(text);
      expect(details.ingredients, isEmpty);
      expect(details.strengths, isEmpty);
      expect(details.forms, isEmpty);
    }
  });

  test('negated product names and package quantities are excluded', () {
    final details = MedicationLabelDetails.fromText(
      'Contains no ibuprofen 200 mg\n48 tablets\nIbuprofen free of aspirin',
    );
    expect(details.ingredients, isEmpty);
    expect(details.strengths, isEmpty);
    expect(details.forms, ['Tablet']);
  });

  test('literal decimal strengths and microgram symbols are normalized', () {
    final details = MedicationLabelDetails.fromText(
      'Loratadine 0.25 mg\nMelatonin 250 µg\n250 μg\n0 mg\n200mgfoo',
    );
    expect(details.strengths, ['0.25 mg', '250 mcg']);
  });

  test('a liquid-filled capsule is a capsule rather than a liquid dose', () {
    final details = MedicationLabelDetails.fromText(
      'Ibuprofen 200 mg liquid-filled capsules',
    );
    expect(details.forms, ['Capsule']);
  });

  test('combination ingredients and readable strengths remain distinct', () {
    final details = MedicationLabelDetails.fromText(
      'Acetaminophen 250 mg\nAspirin 250 mg\nCaffeine 65 mg\nTABLETS',
    );
    expect(details.ingredients, ['Acetaminophen', 'Aspirin', 'Caffeine']);
    expect(details.strengths, ['250 mg', '65 mg']);
    expect(details.forms, ['Tablet']);
  });

  test(
    'incompatible strength, ingredient or form disproves a name-only match',
    () {
      for (final text in [
        'Ibuprofen 400mg tablets',
        'Acetaminophen 200mg tablets',
        'Ibuprofen 200mg capsules',
      ]) {
        expect(
          MedicationLabelDetails.fromText(text).conflictsWith(_tablet),
          isTrue,
          reason: text,
        );
      }
      expect(
        MedicationLabelDetails.fromText('Ibuprofen 0.2g tablets')
            .conflictsWith(_tablet),
        isFalse,
      );
    },
  );

  test(
    'catalog search selects the matching tablet over a same-name capsule',
    () {
      const capsule = MedicationCatalogRecord(
        rxcui: 'wrong-capsule',
        name: 'Advil',
        genericName: 'ibuprofen',
        strength: '200mg',
        form: 'capsule',
      );
      expect(
        matchMedicationCatalogRecord('Advil', [
          capsule,
          _tablet,
        ], extractedText: 'Advil\nIbuprofen 200mg tablets')?.rxcui,
        _tablet.rxcui,
      );
    },
  );

  test('catalog search never selects a contradicted strength', () {
    const wrong = MedicationCatalogRecord(
      rxcui: 'wrong-strength',
      name: 'Advil',
      genericName: 'ibuprofen',
      strength: '400mg',
      form: 'tablet',
    );
    expect(
      matchMedicationCatalogRecord('Advil', [
        wrong,
      ], extractedText: 'Advil\nIbuprofen 200mg tablets'),
      isNull,
    );
  });

  test(
    'readable strength and form prefer a product over a brand-only entry',
    () {
      const brand = MedicationCatalogRecord(rxcui: 'brand', name: 'Advil');
      expect(
        matchMedicationCatalogRecord('Advil', [
          brand,
          _tablet,
        ], extractedText: 'Advil\nIbuprofen 200mg tablets')?.rxcui,
        _tablet.rxcui,
      );
    },
  );
}
