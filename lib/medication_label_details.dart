import 'data/medication_catalog_client.dart';

/// literal ingredient names shared by name detection and label presentation.
const medicationIngredientNames = <String, String>{
  'acetaminophen': 'Acetaminophen',
  'amoxicillin': 'Amoxicillin',
  'aspirin': 'Aspirin',
  'caffeine': 'Caffeine',
  'diphenhydramine': 'Diphenhydramine',
  'ibuprofen': 'Ibuprofen',
  'loratadine': 'Loratadine',
  'melatonin': 'Melatonin',
  'metformin': 'Metformin',
  'naproxen': 'Naproxen',
  'omeprazole': 'Omeprazole',
  'phenylephrine': 'Phenylephrine',
  'prednisone': 'Prednisone',
  'pseudoephedrine': 'Pseudoephedrine',
};

/// a presentation of readable facts, separate from the original ocr evidence.
/// does not infer ingredients from brands, repair words, or create directions.
class MedicationLabelDetails {
  MedicationLabelDetails.fromText(String text)
    : this._(_productLines(text).join('\n'));

  MedicationLabelDetails._(String text)
    : productText = text,
      ingredients = List.unmodifiable(_ingredients(text)),
      strengths = List.unmodifiable(_strengths(text)),
      forms = List.unmodifiable(_forms(text));

  final List<String> ingredients;
  final List<String> strengths;
  final List<String> forms;
  final String productText;

  bool get hasReadableFacts =>
      ingredients.isNotEmpty || strengths.isNotEmpty || forms.isNotEmpty;

  /// prefer a clinical product whose strength/form can be confirmed over a
  /// brand-only catalog entry. this is ranking evidence, not a probability.
  int supportingFieldCount(MedicationCatalogRecord medication) {
    final candidate = MedicationLabelDetails.fromText(
      '${medication.strength}\n${medication.form}\n${medication.name}',
    );
    return (strengths.isNotEmpty &&
                strengths.every(
                  (value) => candidate.strengths.any(
                    (other) => _sameStrength(value, other),
                  ),
                )
            ? 1
            : 0) +
        (forms.isNotEmpty && forms.every(candidate.forms.contains) ? 1 : 0);
  }

  /// readable facts can disprove a name-only catalog match. unknown fields
  /// cannot prove a conflict, and a brand name never fills in missing facts.
  bool conflictsWith(MedicationCatalogRecord medication) {
    final catalogIngredients = _ingredients(
      '${medication.name}\n${medication.genericName}',
    );
    if (catalogIngredients.isNotEmpty &&
        ingredients.any(
          (ingredient) => !catalogIngredients.contains(ingredient),
        )) {
      return true;
    }
    final catalogStrengths = _strengths(
      '${medication.strength}\n${medication.name}',
    );
    if (catalogStrengths.isNotEmpty &&
        strengths.any(
          (strength) => !catalogStrengths.any(
            (candidate) => _sameStrength(strength, candidate),
          ),
        )) {
      return true;
    }
    final catalogForms = _forms(
      medication.form.isNotEmpty ? medication.form : medication.name,
    );
    return forms.isNotEmpty &&
        catalogForms.isNotEmpty &&
        forms.any((form) => !catalogForms.contains(form));
  }
}

Iterable<String> _productLines(String text) sync* {
  var excludedSection = false;
  for (final original in text.split(RegExp(r'[\r\n]+'))) {
    final line = original.trim();
    final heading = line.toLowerCase().replaceFirst(RegExp(r'^[^a-z0-9]+'), '');
    if (RegExp(
      r'^(warnings?\b|directions?\b|uses?\b|inactive ingredients?\b|'
      r'other information\b|do not\b|ask a\b|stop use\b|keep out\b|'
      r'when using\b|compare to\b|take\b)',
    ).hasMatch(heading)) {
      excludedSection = true;
      continue;
    }
    if (RegExp(r'^(drug facts\b|active ingredients?\b)').hasMatch(heading)) {
      excludedSection = false;
    }
    if (excludedSection ||
        RegExp(
          r'\b(contains no|does not contain|without|free of)\b',
          caseSensitive: false,
        ).hasMatch(line)) {
      continue;
    }
    final instruction = RegExp(
      r'\b(?:warnings?|directions?|inactive ingredients?|do not|ask a|stop use|keep out|when using|compare to|take)\b',
      caseSensitive: false,
    ).firstMatch(line);
    if (instruction != null && instruction.start > 0) {
      yield line.substring(0, instruction.start);
      excludedSection = true;
      continue;
    }
    yield line;
  }
}

Iterable<String> _ingredients(String text) => medicationIngredientNames.entries
    .where(
      (entry) =>
          RegExp('\\b${entry.key}\\b', caseSensitive: false).hasMatch(text),
    )
    .map((entry) => entry.value);

Iterable<String> _strengths(String text) sync* {
  final seen = <String>{};
  for (final match in RegExp(
    r'\b(\d+(?:\.\d+)?)\s*(mg|mcg|[µμ]g|g|%)(?![a-z])',
    caseSensitive: false,
  ).allMatches(text)) {
    final number = double.tryParse(match[1]!);
    if (number == null || !number.isFinite || number <= 0) continue;
    final amount = number == number.roundToDouble()
        ? number.toStringAsFixed(0)
        : number.toString();
    final unit = switch (match[2]!.toLowerCase()) {
      'µg' || 'μg' => 'mcg',
      final value => value,
    };
    final strength = '$amount $unit';
    if (seen.add(strength)) yield strength;
  }
}

const _formPatterns = <String, String>{
  'Tablet': r'\b(?:tablets?|caplets?)\b',
  'Capsule': r'\b(?:capsules?|gelcaps?|softgels?)\b',
  'Liquid': r'\b(?:liquid|suspension|oral solution)\b',
  'Cream': r'\bcream\b',
  'Ointment': r'\bointment\b',
  'Patch': r'\bpatch(?:es)?\b',
  'Spray': r'\bspray\b',
  'Injection': r'\binjection\b',
};

Iterable<String> _forms(String text) {
  final forms = _formPatterns.entries
      .where(
        (entry) => RegExp(entry.value, caseSensitive: false).hasMatch(text),
      )
      .map((entry) => entry.key)
      .toSet();
  if ((forms.contains('Tablet') || forms.contains('Capsule')) &&
      !RegExp(
        r'\b(?:suspension|oral solution)\b',
        caseSensitive: false,
      ).hasMatch(text)) {
    forms.remove('Liquid');
  }
  return forms;
}

bool _sameStrength(String first, String second) {
  if (first == second) return true;
  const massFactors = {'mcg': 1.0, 'mg': 1000.0, 'g': 1000000.0};
  final a = first.split(' ');
  final b = second.split(' ');
  final aFactor = massFactors[a.last];
  final bFactor = massFactors[b.last];
  if (aFactor == null || bFactor == null) return false;
  final aValue = double.parse(a.first) * aFactor;
  final bValue = double.parse(b.first) * bFactor;
  return (aValue - bValue).abs() <= aValue.abs() * 1e-10;
}
