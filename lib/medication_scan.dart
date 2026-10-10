import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';
import 'package:pasteboard/pasteboard.dart';

import 'data/medication_catalog_client.dart';
import 'ocr/medication_ocr.dart' as medication_ocr;

/// Data contracts for the medication scan pipeline.
///
/// The detector is intentionally separate from the camera widget so the
/// OCR implementation can change without affecting the review or calendar flow.
enum MedicationScanSource { camera, selectedPhoto }

class MedicationScanRequest {
  const MedicationScanRequest({
    required this.source,
    required this.imageUrl,
    this.imageBytes,
    this.fileName = '',
  });

  const MedicationScanRequest.fromImage({
    required this.imageBytes,
    required this.fileName,
  }) : source = MedicationScanSource.selectedPhoto,
       imageUrl = '';

  final MedicationScanSource source;
  final String imageUrl;
  final Uint8List? imageBytes;
  final String fileName;
}

class MedicationScanResult {
  const MedicationScanResult({
    required this.imageUrl,
    required this.extractedText,
    required this.detectedMedicationName,
    required this.confidence,
    this.imageBytes,
    this.errorMessage = '',
  });

  final String imageUrl;
  final String extractedText;
  final String detectedMedicationName;
  final double confidence;
  final Uint8List? imageBytes;
  final String errorMessage;

  bool get hasError => errorMessage.trim().isNotEmpty;
}

/// Selects the strongest RxNorm result for a name extracted from a label.
///
/// RxNorm product names commonly include strength and dosage form, so an
/// exact string comparison would incorrectly reject valid results such as
/// "Amoxicillin 500 MG Oral Capsule" for the detected name "Amoxicillin".
MedicationCatalogRecord? matchMedicationCatalogRecord(
  String query,
  Iterable<MedicationCatalogRecord> records, {
  String extractedText = '',
}) {
  final normalizedQuery = _normalizeCatalogMedicationName(query);
  if (normalizedQuery.isEmpty) return null;
  final queryTokens = normalizedQuery.split(' ');
  var queryIngredients = _catalogIngredients([normalizedQuery]);
  final queryClaritinD = _hasClaritinD(normalizedQuery);
  final context = _productLabelText(extractedText);
  // Excedrin also names an aspirin-free product. A brand-only query cannot
  // choose the first catalog formulation unless the label supplies all three
  // ingredients of the standard combination.
  if (normalizedQuery == 'excedrin') {
    queryIngredients = _catalogIngredients([_normalizeMedicationName(context)]);
    if (queryIngredients.length != _excedrinMigraineIngredients.length ||
        !queryIngredients.containsAll(_excedrinMigraineIngredients)) {
      return null;
    }
  }
  final duration = _labelDuration(query) ?? _labelDuration(context);
  final strengths = _labelStrengths(context);
  final ingredientStrengths = _labelIngredientStrengths(context);
  if (queryIngredients.length > 1 &&
      ingredientStrengths.values.any((values) => values.length > 1)) {
    return null;
  }
  MedicationCatalogRecord? bestRecord;
  var bestScore = 0;

  for (final record in records) {
    final names = [record.name, record.genericName, record.synonym]
        .map(_normalizeCatalogMedicationName)
        .where((name) => name.isNotEmpty)
        .toList();
    if (queryIngredients.isNotEmpty &&
        !_hasCompatibleExplicitIngredients(record, queryIngredients)) {
      continue;
    }
    final recordIngredients = _catalogIngredients(names);
    // A shared brand/ingredient token is not enough to match a different
    // formulation. Include all fields so a short synonym cannot conceal the
    // combination named in the product or generic name.
    if (queryIngredients.isNotEmpty &&
        recordIngredients.isNotEmpty &&
        (queryIngredients.length != recordIngredients.length ||
            !recordIngredients.containsAll(queryIngredients))) {
      continue;
    }
    if (queryClaritinD &&
        !names.any(_hasClaritinD) &&
        !recordIngredients.containsAll({'loratadine', 'pseudoephedrine'})) {
      continue;
    }
    final recordText =
        '${record.name} ${record.genericName} ${record.synonym} ${record.strength}';
    final recordDuration = _labelDuration(recordText);
    if (duration != null &&
        recordDuration != null &&
        duration != recordDuration) {
      continue;
    }
    final recordStrengths = _labelStrengths(recordText);
    final recordIngredientStrengths = _labelIngredientStrengths(recordText);
    // Associate a dose with its ingredient. A set of bare numbers loses the
    // repeated 250 mg strengths on a three-ingredient Excedrin label and can
    // also accept a catalog product with the doses assigned the wrong way.
    if (queryIngredients.length > 1 &&
        ingredientStrengths.entries.any((entry) {
          final recordValues = recordIngredientStrengths[entry.key];
          return recordValues != null && !recordValues.containsAll(entry.value);
        })) {
      continue;
    }
    // Two readable strengths on a combination label are stronger evidence
    // than a short brand synonym. A single OCR number is only a ranking hint.
    if (queryIngredients.length > 1 &&
        strengths.length == queryIngredients.length &&
        recordStrengths.length == queryIngredients.length &&
        !strengths.containsAll(recordStrengths)) {
      continue;
    }
    var recordScore = 0;
    for (final name in names) {
      if (name == normalizedQuery) {
        recordScore = recordScore < 1000 ? 1000 : recordScore;
        continue;
      }
      if (name.startsWith('$normalizedQuery ')) {
        recordScore = recordScore < 900 ? 900 : recordScore;
        continue;
      }
      final nameTokens = name.split(' ');
      if (queryTokens.every(nameTokens.contains)) {
        recordScore = recordScore < 700 ? 700 : recordScore;
      }
    }
    // RxNorm may return the generic combination for a branded query, or a
    // brand-only record for a generic combination. Require the complete known
    // ingredient set so neither plain Claritin nor aspirin-free Excedrin can
    // stand in for a different combination.
    if (recordScore == 0 &&
        (queryIngredients.containsAll({'loratadine', 'pseudoephedrine'}) ||
            queryIngredients.contains('caffeine')) &&
        recordIngredients.length == queryIngredients.length &&
        recordIngredients.containsAll(queryIngredients)) {
      recordScore = 600;
    }
    if (recordScore > 0) {
      if (duration != null && duration == recordDuration) recordScore += 200;
      recordScore += recordStrengths.where(strengths.contains).length * 150;
    }
    if (recordScore > bestScore) {
      bestScore = recordScore;
      bestRecord = record;
    }
  }
  return bestRecord;
}

bool _hasCompatibleExplicitIngredients(
  MedicationCatalogRecord record,
  Set<String> expected,
) {
  // A brand synonym cannot fill in an ingredient missing from an explicit
  // formula. Unknown slash-separated ingredients must not disappear merely
  // because the camera's alias list does not recognize their names.
  for (final field in [record.name, record.genericName]) {
    final withoutBrand = field.replaceAll(RegExp(r'\[[^\]]*\]'), '');
    final components = withoutBrand.split(
      RegExp(r'/|,|\+|\band\b', caseSensitive: false),
    );
    final explicit = <String>{};
    var unknownComponent = false;
    for (final component in components) {
      final normalized = _normalizeMedicationName(component);
      if (normalized.isEmpty) continue;
      final tokens = normalized.split(' ').toSet();
      final ingredients = _genericMedicationAliases.keys
          .where(tokens.contains)
          .toSet();
      explicit.addAll(ingredients);
      if (components.length > 1 && ingredients.isEmpty) {
        if (_brandMedicationAliases.keys.any(tokens.contains)) continue;
        // A concentration denominator is not another active ingredient.
        // For example, do not treat "5 mL" in "12.5 mg / 5 mL" as a drug.
        if (!RegExp(r'^(?:\d+(?:\s+\d+)?\s*)?(?:ml|l|mg|mcg|g)\b')
            .hasMatch(normalized)) {
          unknownComponent = true;
        }
      }
    }
    if (unknownComponent ||
        (explicit.isNotEmpty &&
            (explicit.length != expected.length ||
                !explicit.containsAll(expected)))) {
      return false;
    }
  }
  return true;
}

String _normalizeMedicationName(String value) =>
    value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();

String _normalizeCatalogMedicationName(String value) =>
    _normalizeMedicationName(value).replaceAllMapped(
      RegExp(r'\bclaritin\s*d(?:\s*(12|24))?\b'),
      (match) => 'claritin d${match[1] == null ? '' : ' ${match[1]}'}',
    );

bool _hasClaritinD(String name) => RegExp(r'\bclaritin d\b').hasMatch(name);

int? _labelDuration(String text) {
  final normalized = _normalizeCatalogMedicationName(text);
  final durations =
      RegExp(r'\b(12|24)\s*(?:hour|hours|hr|hrs)\b|\bclaritin d (12|24)\b')
          .allMatches(normalized)
          .map((match) => int.parse(match[1] ?? match[2]!))
          .toSet();
  return durations.length == 1 ? durations.single : null;
}

Set<String> _labelStrengths(String text) =>
    RegExp(
      r'\b(\d+(?:\.\d+)?)\s*(mg|mcg|g)\b',
      caseSensitive: false,
    ).allMatches(text).map((match) {
      return '${double.parse(match[1]!)} ${match[2]!.toLowerCase()}';
    }).toSet();

Map<String, Set<String>> _labelIngredientStrengths(String text) {
  final strengths = <String, Set<String>>{};
  for (final ingredient in _genericMedicationAliases.keys) {
    final pattern = RegExp(
      '\\b$ingredient\\s+(?:(?:hcl|hydrochloride|sulfate)\\s+)?'
      r'(\d+(?:\.\d+)?)\s*(mg|mcg|g)\b',
      caseSensitive: false,
    );
    for (final match in pattern.allMatches(text)) {
      strengths
          .putIfAbsent(ingredient, () => {})
          .add('${double.parse(match[1]!)} ${match[2]!.toLowerCase()}');
    }
  }
  return strengths;
}

const _excedrinMigraineIngredients = {'acetaminophen', 'aspirin', 'caffeine'};
const _excedrinTensionIngredients = {'acetaminophen', 'caffeine'};

Set<String> _excedrinFormulations(String normalized) {
  final formulations = <String>{};
  if (RegExp(r'\bmigraine(?: relief)?\b').hasMatch(normalized)) {
    formulations.add('Excedrin Migraine');
  }
  if (RegExp(r'\bextra strength\b').hasMatch(normalized)) {
    formulations.add('Excedrin Extra Strength');
  }
  if (RegExp(r'\btension headache\b|\baspirin free\b').hasMatch(normalized)) {
    formulations.add('Excedrin Tension Headache');
  }
  return formulations;
}

Map<String, double> _excedrinOcrFormulations(String normalized) {
  final formulations = {
    for (final name in _excedrinFormulations(normalized)) name: .94,
  };
  // A cylindrical label can compress one letter in MIGRAINE even when the
  // independently read Excedrin brand is intact. Keep this correction local
  // to Excedrin detection and cap its confidence; never fuzzy-match catalog
  // formulations or infer a variant from the brand alone.
  if (!formulations.containsKey('Excedrin Migraine') &&
      normalized
          .split(' ')
          .any(
            (token) =>
                !token.startsWith('migraine') &&
                _editDistanceAtMostOne(token, 'migraine'),
          )) {
    formulations['Excedrin Migraine'] = .7;
  }
  return formulations;
}

Set<String> _excedrinFormulationIngredients(String name) =>
    name == 'Excedrin Tension Headache'
    ? _excedrinTensionIngredients
    : _excedrinMigraineIngredients;

const _genericMedicationAliases = <String, String>{
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

const _brandMedicationAliases = <String, String>{
  'advil': 'Advil',
  'aleve': 'Aleve',
  'benadryl': 'Benadryl',
  'claritin': 'Claritin',
  'dayquil': 'DayQuil',
  'excedrin': 'Excedrin',
  'lipitor': 'Lipitor',
  'motrin': 'Motrin',
  'nyquil': 'NyQuil',
  'pepcid': 'Pepcid',
  'tylenol': 'Tylenol',
  'zoloft': 'Zoloft',
};

Set<String> _catalogIngredients(Iterable<String> names) {
  final ingredients = <String>{};
  for (final name in names) {
    final tokens = name.split(' ').toSet();
    ingredients.addAll(_genericMedicationAliases.keys.where(tokens.contains));
    if (_hasClaritinD(name)) {
      ingredients.addAll({'loratadine', 'pseudoephedrine'});
    } else if (tokens.contains('claritin')) {
      ingredients.add('loratadine');
    } else if (tokens.contains('benadryl')) {
      ingredients.add('diphenhydramine');
    }
    if (tokens.contains('excedrin')) {
      for (final formulation in _excedrinFormulations(name)) {
        ingredients.addAll(_excedrinFormulationIngredients(formulation));
      }
    }
  }
  return ingredients;
}

abstract class MedicationScanDetector {
  Future<MedicationScanResult> detect(MedicationScanRequest request);
}

class MedicationPickedImage {
  const MedicationPickedImage({required this.bytes, required this.fileName});

  final Uint8List bytes;
  final String fileName;
}

Future<MedicationPickedImage?> pickMedicationPhoto() async {
  final file = await ImagePicker().pickImage(source: ImageSource.gallery);
  if (file == null) return null;
  return MedicationPickedImage(
    bytes: await file.readAsBytes(),
    fileName: file.name,
  );
}

/// Opens the native camera and returns the photo the person confirms.
/// Cancelling the camera returns null and does not start a medication scan.
Future<MedicationPickedImage?> captureMedicationPhoto({
  ImagePicker? picker,
}) async {
  final file = await (picker ?? ImagePicker()).pickImage(
    source: ImageSource.camera,
    requestFullMetadata: false,
  );
  if (file == null) return null;
  return MedicationPickedImage(
    bytes: await file.readAsBytes(),
    fileName: file.name,
  );
}

/// Reads a PNG/JPEG image from the system clipboard when the platform exposes
/// image clipboard data. Text-only clipboard contents return null.
Future<MedicationPickedImage?> pasteMedicationPhoto() async {
  final bytes = await Pasteboard.image;
  if (bytes == null || bytes.isEmpty) return null;
  return MedicationPickedImage(
    bytes: bytes,
    fileName: 'pasted-medication-image.png',
  );
}

/// OCR-backed detector for user-selected and pasted images.
///
/// The platform adapter uses ML Kit on Android/iOS and Tesseract.js in the
/// browser. Every image goes through OCR before catalog verification.
class MedicationOcrDetector implements MedicationScanDetector {
  const MedicationOcrDetector();

  @override
  Future<MedicationScanResult> detect(MedicationScanRequest request) async {
    if (request.imageBytes == null || request.imageBytes!.isEmpty) {
      return MedicationScanResult(
        imageUrl: request.imageUrl,
        imageBytes: request.imageBytes,
        extractedText: '',
        detectedMedicationName: '',
        confidence: 0,
        errorMessage:
            'The image did not contain any photo data. Try again or search '
            'for the medication manually.',
      );
    }

    medication_ocr.MedicationOcrEvidence evidence;
    try {
      evidence = await medication_ocr.recognizeMedicationEvidence(
        request.imageBytes!,
        fileName: request.fileName,
      );
    } catch (_) {
      return MedicationScanResult(
        imageUrl: request.imageUrl,
        imageBytes: request.imageBytes,
        extractedText: '',
        detectedMedicationName: '',
        confidence: 0,
        errorMessage:
            'The image could not be processed. Try again or search for the '
            'medication manually.',
      );
    }
    final extractedText = evidence.text;
    if (extractedText.trim().isEmpty) {
      return MedicationScanResult(
        imageUrl: request.imageUrl,
        imageBytes: request.imageBytes,
        extractedText: '',
        detectedMedicationName: '',
        confidence: 0,
        errorMessage:
            'We could not read text from this image. Try a sharper photo '
            'with the medication name facing the camera.',
      );
    }

    final detection = _detectMedicationName(extractedText);
    return MedicationScanResult(
      imageUrl: request.imageUrl,
      imageBytes: request.imageBytes,
      extractedText: extractedText.trim(),
      detectedMedicationName: detection.name ?? '',
      confidence: evidence.recoveredUncertainText && detection.confidence > .65
          ? .65
          : detection.confidence,
      errorMessage: detection.name == null
          ? 'We could not identify a medication from this photo. Retake it '
                'with the name facing the camera, hold steady, and use even '
                'lighting. You can also search for the medication manually.'
          : '',
    );
  }
}

/// Extracts a medication name conservatively from OCR output.
///
/// Brand aliases are checked before generic names because OTC labels usually
/// lead with the brand name (for example, "Advil"). The line fallback keeps
/// the detector useful for other labels without inventing a name when OCR is
/// too noisy; an unfamiliar name needs a readable strength or dosage form,
/// and RxNorm still verifies the returned candidate before scheduling.
String? detectMedicationName(String extractedText) =>
    _detectMedicationName(extractedText).name;

({String? name, double confidence}) _detectMedicationName(
  String extractedText,
) {
  // Preserve OCR evidence, but do not identify a product from a medication
  // mentioned only in directions, warnings, or an inactive ingredient list.
  final productText = _productLabelText(extractedText);
  final normalized = _normalizeMedicationName(productText);
  if (normalized.isEmpty) return (name: null, confidence: .25);

  final tokens = normalized.split(' ');
  final ingredients = <String, double>{};
  final brands = <String, double>{};
  void remember(Map<String, double> matches, String name, double confidence) {
    if (confidence > (matches[name] ?? 0)) matches[name] = confidence;
  }

  for (var index = 0; index < tokens.length; index++) {
    // Check the whole brand including its suffix before fuzzy matching the
    // shorter base name. OCR often separates D or attaches the hour number.
    for (var count = 1; count <= 3 && index + count <= tokens.length; count++) {
      final joined = tokens.sublist(index, index + count).join();
      final suffix = RegExp(r'^(.+)d(?:12|24)?$').firstMatch(joined);
      if (suffix != null) {
        final confidence = _medicationAliasConfidence(suffix[1]!, 'claritin');
        if (confidence != null) remember(brands, 'Claritin-D', confidence);
      }
    }
    for (final entry in _brandMedicationAliases.entries) {
      final confidence = _medicationAliasAt(tokens, index, entry.key);
      if (confidence != null) {
        remember(brands, entry.value, confidence);
      }
    }
    for (final entry in _genericMedicationAliases.entries) {
      final confidence = _medicationAliasAt(tokens, index, entry.key);
      if (confidence != null) {
        remember(ingredients, entry.key, confidence);
      }
    }
  }

  if (brands.containsKey('Claritin-D')) {
    brands.remove('Claritin');
  } else if (brands.containsKey('Claritin') &&
      ingredients.keys.toSet().containsAll({'loratadine', 'pseudoephedrine'})) {
    final evidence = [
      brands['Claritin']!,
      ingredients['loratadine']!,
      ingredients['pseudoephedrine']!,
      .85,
    ].reduce((first, second) => first < second ? first : second);
    brands.remove('Claritin');
    brands['Claritin-D'] = evidence;
  } else if (brands.containsKey('Claritin') &&
      _hasUnresolvedClaritinSuffix(productText)) {
    // A clipped or unreadable formulation suffix must not become plain
    // Claritin. A later complete D variant above still wins over this noise.
    return (name: null, confidence: .25);
  }
  // Conflicting brands require review instead of whichever token OCR listed
  // first. Likewise, keep a readable combination intact when no brand is read.
  if (brands.length > 1) return (name: null, confidence: .25);
  if (brands.containsKey('Excedrin')) {
    final formulations = _excedrinOcrFormulations(normalized);
    if (formulations.length > 1) return (name: null, confidence: .25);
    if (formulations.length == 1) {
      final name = formulations.keys.single;
      final expectedIngredients = _excedrinFormulationIngredients(name);
      if (!expectedIngredients.containsAll(ingredients.keys)) {
        return (name: null, confidence: .25);
      }
      return (
        name: name,
        confidence: brands['Excedrin']! < formulations[name]!
            ? brands['Excedrin']!
            : formulations[name]!,
      );
    }
    if (ingredients.length != _excedrinMigraineIngredients.length ||
        !ingredients.keys.toSet().containsAll(_excedrinMigraineIngredients)) {
      return (name: null, confidence: .25);
    }
    return (
      name: 'Excedrin',
      confidence: [
        brands['Excedrin']!,
        ...ingredients.values,
      ].reduce((first, second) => first < second ? first : second),
    );
  }
  if (brands.length == 1) {
    return (name: brands.keys.single, confidence: brands.values.single);
  }
  if (ingredients.isNotEmpty) {
    final sorted = ingredients.keys.toList()..sort();
    return (
      name: sorted.map((name) => _genericMedicationAliases[name]!).join(' / '),
      confidence: ingredients.values.reduce(
        (first, second) => first < second ? first : second,
      ),
    );
  }

  // A symptom, package slogan, or punctuation fragment is not a medication
  // name. Retain support for unfamiliar medicines only when the same line
  // contains a name-shaped phrase followed by product evidence.
  final labelName = RegExp(
    r'^([A-Za-z][A-Za-z-]{3,}(?:\s+[A-Za-z][A-Za-z-]{2,})?)\s+'
    r'(?:\d+(?:\.\d+)?\s*(?:mg|mcg|g)\b|(?:tablets?|capsules?)\b)',
    caseSensitive: false,
  );
  for (final line in productText.split(RegExp(r'[\r\n]+'))) {
    if (_looksLikeInstruction(line)) continue;
    final match = labelName.firstMatch(line.trim());
    if (match == null) continue;
    final candidate = match[1]!;
    final words = candidate.toLowerCase().split(RegExp(r'\s+'));
    if (words.any((word) => !RegExp(r'[aeiouy]').hasMatch(word)) ||
        words.any(
          const {
            'allergy',
            'relief',
            'antihistamine',
            'tablets',
            'capsules',
            'contains',
            'ultratabs',
            'strength',
            'extra',
            'maximum',
          }.contains,
        )) {
      continue;
    }
    return (name: candidate, confidence: .35);
  }
  return (name: null, confidence: .25);
}

double? _medicationAliasAt(List<String> tokens, int index, String alias) {
  final confidence = _medicationAliasConfidence(tokens[index], alias);
  if (confidence == .94) return confidence;
  if (index + 1 >= tokens.length) return confidence;
  final first = tokens[index];
  final second = tokens[index + 1];
  final joined = '$first$second';
  // Joining exact fragments also handles a single trailing OCR letter, but
  // fuzzy joins require two substantial fragments to avoid absorbing suffixes.
  if (joined == alias) return .85;
  if (confidence != null) return confidence;
  if (first.length >= 2 &&
      second.length >= 2 &&
      _medicationAliasConfidence(joined, alias) != null) {
    return .65;
  }
  return null;
}

bool _hasUnresolvedClaritinSuffix(String text) =>
    RegExp(
      r'\b([a-z0-9]+)[ \t]*[-‐‑‒–—−][ \t]*([a-z0-9]\b|$)',
      caseSensitive: false,
      multiLine: true,
    ).allMatches(text.toLowerCase()).any((match) {
      return _medicationAliasConfidence(match[1]!, 'claritin') != null &&
          match[2] != 'd';
    });

double? _medicationAliasConfidence(String token, String alias) {
  if (token == alias) return .94;
  if (token.length < 5) return null;
  // A trailing character can be a formulation suffix, not an OCR typo.
  if (token.startsWith(alias)) return null;
  if (_editDistanceAtMostOne(token, alias)) return .7;
  String fold(String value) =>
      value.replaceAll('1', 'i').replaceAll('l', 'i').replaceAll('0', 'o');
  return fold(token) == fold(alias) ? .7 : null;
}

String _productLabelText(String text) => text
    .split(RegExp(r'[\r\n]+'))
    .where((line) => !_looksLikeNonProductText(line))
    .join('\n');

bool _looksLikeNonProductText(String line) {
  final normalized = _normalizeMedicationName(line);
  return (_looksLikeInstruction(line) &&
          !normalized.startsWith('active ingredient')) ||
      RegExp(
        r'^(warnings?\b|do not\b|ask a\b|stop use\b|keep out\b|'
        r'inactive ingredients?\b|compare to\b)',
      ).hasMatch(normalized) ||
      RegExp(r'\b(contains no|does not contain|without|free of)\b')
          .hasMatch(normalized);
}

bool _editDistanceAtMostOne(String first, String second) {
  if ((first.length - second.length).abs() > 1) return false;
  if (first == second) return true;
  if (first.length == second.length) {
    var differences = 0;
    for (var index = 0; index < first.length; index++) {
      if (first[index] != second[index] && ++differences > 1) return false;
    }
    return differences == 1;
  }
  final shorter = first.length < second.length ? first : second;
  final longer = first.length < second.length ? second : first;
  var shortIndex = 0;
  var longIndex = 0;
  var skipped = false;
  while (shortIndex < shorter.length && longIndex < longer.length) {
    if (shorter[shortIndex] == longer[longIndex]) {
      shortIndex++;
      longIndex++;
    } else if (skipped) {
      return false;
    } else {
      skipped = true;
      longIndex++;
    }
  }
  return true;
}

bool _looksLikeInstruction(String line) {
  final normalized = _normalizeMedicationName(line);
  return normalized.startsWith('take ') ||
      normalized.startsWith('directions ') ||
      normalized.startsWith('active ingredient ') ||
      normalized.startsWith('uses ');
}
