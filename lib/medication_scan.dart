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
  final queryIngredients = _catalogIngredients([normalizedQuery]);
  final queryClaritinD = _hasClaritinD(normalizedQuery);
  final context = _productLabelText(extractedText);
  final duration = _labelDuration(query) ?? _labelDuration(context);
  final strengths = _labelStrengths(context);
  MedicationCatalogRecord? bestRecord;
  var bestScore = 0;

  for (final record in records) {
    final names = [record.name, record.genericName, record.synonym]
        .map(_normalizeCatalogMedicationName)
        .where((name) => name.isNotEmpty)
        .toList();
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
    // brand-only record for a generic combination. Require both ingredients;
    // plain Claritin is never an alternative for Claritin-D.
    if (recordScore == 0 &&
        queryIngredients.containsAll({'loratadine', 'pseudoephedrine'}) &&
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

const _genericMedicationAliases = <String, String>{
  'acetaminophen': 'Acetaminophen',
  'amoxicillin': 'Amoxicillin',
  'aspirin': 'Aspirin',
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

    String extractedText;
    try {
      extractedText = await medication_ocr.recognizeMedicationText(
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
      confidence: detection.confidence,
    );
  }
}

/// Extracts a medication name conservatively from OCR output.
///
/// Brand aliases are checked before generic names because OTC labels usually
/// lead with the brand name (for example, "Advil"). The line fallback keeps
/// the detector useful for other labels without inventing a name when OCR is
/// too noisy; RxNorm still verifies the returned candidate before scheduling.
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

  final firstUsefulLine = productText
      .split(RegExp(r'[\r\n]+'))
      .map((line) => line.trim())
      .firstWhere(
        (line) =>
            line.length >= 3 &&
            RegExp(r'[A-Za-z]').hasMatch(line) &&
            !_looksLikeInstruction(line),
        orElse: () => '',
      );
  if (firstUsefulLine.isEmpty) return (name: null, confidence: .25);
  final candidate = firstUsefulLine
      .split(RegExp(r'[.;|]'))
      .first
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  return candidate.length > 48
      ? (name: null, confidence: .25)
      : (name: candidate, confidence: .35);
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
