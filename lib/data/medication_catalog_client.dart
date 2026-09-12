import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class MedicationCatalogRecord {
  const MedicationCatalogRecord({
    required this.rxcui,
    required this.name,
    this.genericName = '',
    this.synonym = '',
    this.strength = '',
    this.form = '',
    this.route = '',
    this.tty = '',
    this.sourceVersion = '',
    this.labelUrl,
    this.warnings = const [],
    this.indications = const [],
  });

  final String rxcui;
  final String name;
  final String genericName;
  final String synonym;
  final String strength;
  final String form;
  final String route;
  final String tty;
  final String sourceVersion;
  final String? labelUrl;
  final List<String> warnings;
  final List<String> indications;

  String get id => rxcui;

  String get description {
    final parts = <String>[
      if (genericName.isNotEmpty &&
          genericName.toLowerCase() != name.toLowerCase())
        genericName,
      if (strength.isNotEmpty) strength,
      if (form.isNotEmpty) form,
    ];
    return parts.join(' · ');
  }

  String get doseDescription => [
    if (strength.isNotEmpty) strength,
    if (form.isNotEmpty) form,
  ].join(' · ');

  MedicationCatalogRecord copyWith({
    String? genericName,
    String? synonym,
    String? strength,
    String? form,
    String? route,
    String? sourceVersion,
    String? labelUrl,
    List<String>? warnings,
    List<String>? indications,
  }) {
    return MedicationCatalogRecord(
      rxcui: rxcui,
      name: name,
      genericName: genericName ?? this.genericName,
      synonym: synonym ?? this.synonym,
      strength: strength ?? this.strength,
      form: form ?? this.form,
      route: route ?? this.route,
      tty: tty,
      sourceVersion: sourceVersion ?? this.sourceVersion,
      labelUrl: labelUrl ?? this.labelUrl,
      warnings: warnings ?? this.warnings,
      indications: indications ?? this.indications,
    );
  }
}

class CatalogSearchPage {
  const CatalogSearchPage({required this.items, required this.sourceVersion});

  final List<MedicationCatalogRecord> items;
  final String sourceVersion;
}

abstract class MedicationCatalogClient {
  Future<CatalogSearchPage> search(String query);

  Future<MedicationCatalogRecord> getDetails(String rxcui);
}

class MedicationCatalogException implements Exception {
  const MedicationCatalogException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class MedicationCatalogRateLimitException extends MedicationCatalogException {
  const MedicationCatalogRateLimitException()
    : super(
        'The medication service is temporarily rate-limited.',
        statusCode: 429,
      );
}

class RxNormMedicationCatalogClient implements MedicationCatalogClient {
  RxNormMedicationCatalogClient({http.Client? client})
    : _client = client ?? http.Client();

  static const _rxNormHost = 'rxnav.nlm.nih.gov';
  static const _openFdaHost = 'api.fda.gov';
  static const _defaultVersion = 'current';
  static const _requestTimeout = Duration(seconds: 10);
  static const _maxResults = 20;

  final http.Client _client;
  final Map<String, CatalogSearchPage> _searchCache = {};
  final Map<String, MedicationCatalogRecord> _detailsCache = {};
  String? _sourceVersion;
  DateTime? _lastDetailRequest;

  @override
  Future<CatalogSearchPage> search(String query) async {
    final normalized = query.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (normalized.length < 2) {
      return CatalogSearchPage(
        items: const [],
        sourceVersion: _sourceVersion ?? _defaultVersion,
      );
    }

    final cacheKey = normalized.toLowerCase();
    final cached = _searchCache[cacheKey];
    if (cached != null) return cached;

    final uri = Uri.https(_rxNormHost, '/REST/Prescribe/drugs.json', {
      'name': normalized,
      'expand': 'psn',
      'maxEntries': '20',
    });
    final response = await _get(uri);
    final data = _decodeObject(response.body, 'RxNorm');
    final version = await _loadVersion();
    final records = _parseRxNormResults(data, version);
    final page = CatalogSearchPage(
      items: records.take(_maxResults).toList(growable: false),
      sourceVersion: version,
    );
    _searchCache[cacheKey] = page;
    return page;
  }

  @override
  Future<MedicationCatalogRecord> getDetails(String rxcui) async {
    final normalized = rxcui.trim();
    if (normalized.isEmpty) {
      throw const MedicationCatalogException(
        'A medication identifier is required.',
      );
    }
    final cached = _detailsCache[normalized];
    if (cached != null) return cached;

    final lastRequest = _lastDetailRequest;
    if (lastRequest != null) {
      final elapsed = DateTime.now().difference(lastRequest);
      const minimumGap = Duration(milliseconds: 100);
      if (elapsed < minimumGap) {
        await Future<void>.delayed(minimumGap - elapsed);
      }
    }
    _lastDetailRequest = DateTime.now();

    final rxNormUri = Uri.https(
      _rxNormHost,
      '/REST/Prescribe/rxcui/$normalized/properties.json',
    );
    final rxNormResponse = await _get(rxNormUri);
    final rxNormData = _decodeObject(rxNormResponse.body, 'RxNorm');
    final version = await _loadVersion();
    final base = _parseRxNormProperties(
      rxNormData,
      normalized,
    ).copyWith(sourceVersion: version);

    MedicationCatalogRecord record = base;
    try {
      final fdaUri = Uri.https(_openFdaHost, '/drug/label.json', {
        'search': 'openfda.rxcui:$normalized',
        'limit': '1',
      });
      final fdaResponse = await _get(fdaUri, allowNotFound: true);
      if (fdaResponse.statusCode == 200) {
        final fdaData = _decodeObject(fdaResponse.body, 'openFDA');
        record = _mergeOpenFda(record, fdaData);
      }
    } on MedicationCatalogRateLimitException {
      rethrow;
    } on MedicationCatalogException {
      // RxNorm remains a valid detail source when no FDA label is available.
    }

    _detailsCache[normalized] = record;
    return record;
  }

  Future<http.Response> _get(Uri uri, {bool allowNotFound = false}) async {
    try {
      final response = await _client.get(uri).timeout(_requestTimeout);
      if (response.statusCode == 429) {
        throw const MedicationCatalogRateLimitException();
      }
      if (response.statusCode == 404 && allowNotFound) return response;
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw MedicationCatalogException(
          'Medication service returned HTTP ${response.statusCode}.',
          statusCode: response.statusCode,
        );
      }
      return response;
    } on TimeoutException {
      throw const MedicationCatalogException(
        'The medication service timed out. Check your connection and try again.',
      );
    } on MedicationCatalogException {
      rethrow;
    } catch (_) {
      throw const MedicationCatalogException(
        'The medication service is unavailable. Check your connection and try again.',
      );
    }
  }

  Map<String, dynamic> _decodeObject(String body, String source) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {
      // Fall through to the consistent user-facing exception below.
    }
    throw MedicationCatalogException('$source returned an invalid response.');
  }

  Future<String> _loadVersion() async {
    final current = _sourceVersion;
    if (current != null) return current;
    try {
      final response = await _get(
        Uri.https(_rxNormHost, '/REST/Prescribe/version.json'),
      );
      final data = _decodeObject(response.body, 'RxNorm');
      final version = _firstString([
        _valueAt(data, ['rxnormVersion']),
        _valueAt(data, ['version']),
      ]);
      _sourceVersion = version.isEmpty ? _defaultVersion : version;
    } on MedicationCatalogException {
      _sourceVersion = _defaultVersion;
    }
    return _sourceVersion!;
  }

  List<MedicationCatalogRecord> _parseRxNormResults(
    Map<String, dynamic> data,
    String sourceVersion,
  ) {
    final drugGroup = data['drugGroup'];
    final groups = drugGroup is Map ? drugGroup['conceptGroup'] : null;
    if (groups is! Iterable) return const [];

    final records = <MedicationCatalogRecord>[];
    for (final group in groups) {
      if (group is! Map) continue;
      final tty = group['tty']?.toString() ?? '';
      final concepts = group['conceptProperties'];
      if (concepts is! Iterable) continue;
      for (final concept in concepts) {
        if (concept is! Map) continue;
        final rxcui = concept['rxcui']?.toString().trim() ?? '';
        final name = concept['name']?.toString().trim() ?? '';
        if (rxcui.isEmpty || name.isEmpty) continue;
        final synonym = concept['synonym']?.toString().trim() ?? '';
        final displayName = concept['psn']?.toString().trim().isNotEmpty == true
            ? concept['psn'].toString().trim()
            : name;
        records.add(
          _recordFromName(
            rxcui: rxcui,
            name: displayName,
            synonym: synonym,
            tty: tty,
            sourceVersion: sourceVersion,
          ),
        );
      }
    }
    final byId = <String, MedicationCatalogRecord>{};
    for (final record in records) {
      final existing = byId[record.rxcui];
      if (existing == null || _rank(record) < _rank(existing)) {
        byId[record.rxcui] = record;
      }
    }
    final unique = byId.values.toList()
      ..sort((first, second) => first.name.compareTo(second.name));
    return unique;
  }

  MedicationCatalogRecord _parseRxNormProperties(
    Map<String, dynamic> data,
    String rxcui,
  ) {
    final properties = data['properties'];
    final values = properties is Map ? properties : data;
    final name = values['name']?.toString().trim() ?? 'Medication';
    final synonym = values['synonym']?.toString().trim() ?? '';
    return _recordFromName(
      rxcui: rxcui,
      name: name,
      synonym: synonym,
      tty: values['tty']?.toString() ?? '',
      sourceVersion: _sourceVersion ?? _defaultVersion,
    );
  }

  MedicationCatalogRecord _recordFromName({
    required String rxcui,
    required String name,
    required String synonym,
    required String tty,
    required String sourceVersion,
  }) {
    final strength = _extractStrength(name);
    final form = _extractForm(name);
    final route = _extractRoute(name);
    final generic = _genericName(name, strength, form, route);
    return MedicationCatalogRecord(
      rxcui: rxcui,
      name: name,
      genericName: generic,
      synonym: synonym,
      strength: strength,
      form: form,
      route: route,
      tty: tty,
      sourceVersion: sourceVersion,
    );
  }

  MedicationCatalogRecord _mergeOpenFda(
    MedicationCatalogRecord base,
    Map<String, dynamic> data,
  ) {
    final results = data['results'];
    if (results is! Iterable || results.isEmpty || results.first is! Map) {
      return base;
    }
    final result = Map<String, dynamic>.from(results.first as Map);
    final openFda = result['openfda'];
    final metadata = openFda is Map
        ? Map<String, dynamic>.from(openFda)
        : const <String, dynamic>{};
    final genericName = _firstString([
      _firstListString(metadata['generic_name']),
      base.genericName,
    ]);
    final form = _firstString([
      _firstListString(metadata['dosage_form']),
      base.form,
    ]);
    final route = _firstString([
      _firstListString(metadata['route']),
      base.route,
    ]);
    final strength = _firstString([
      _firstListString(result['dosage_forms_and_strengths']),
      base.strength,
    ]);
    final setId = _firstListString(metadata['spl_set_id']);
    final labelUrl = setId.isEmpty
        ? null
        : 'https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=$setId';
    return base.copyWith(
      genericName: genericName,
      form: form,
      route: route,
      strength: strength,
      labelUrl: labelUrl,
      warnings: _stringList(result['warnings']),
      indications: _stringList(result['indications_and_usage']),
    );
  }

  static int _rank(MedicationCatalogRecord record) {
    return switch (record.tty.toUpperCase()) {
      'GPCK' || 'BPCK' => 4,
      'SBD' => 2,
      _ when record.name.toLowerCase().contains('pack') => 3,
      _ when record.name.toLowerCase().contains('brand') => 2,
      _ => 0,
    };
  }

  static String _extractStrength(String value) {
    final match = RegExp(
      r'(\d+(?:\.\d+)?\s*(?:mg|mcg|g|kg|ml|l|iu|unit(?:s)?)(?:\s*/\s*\d+(?:\.\d+)?\s*(?:ml|l))?)',
      caseSensitive: false,
    ).firstMatch(value);
    return match?.group(1)?.trim() ?? '';
  }

  static String _extractForm(String value) {
    const forms = [
      'extended release tablet',
      'delayed release tablet',
      'oral tablet',
      'tablet',
      'capsule',
      'oral solution',
      'solution',
      'suspension',
      'injection',
      'cream',
      'ointment',
      'inhaler',
      'patch',
      'powder',
      'spray',
      'suppository',
    ];
    final lower = value.toLowerCase();
    for (final form in forms) {
      if (lower.contains(form)) {
        final normalized = form
            .replaceFirst('oral ', '')
            .replaceFirst('extended release ', 'extended-release ')
            .replaceFirst('delayed release ', 'delayed-release ');
        return _titleCase(normalized);
      }
    }
    return '';
  }

  static String _extractRoute(String value) {
    final lower = value.toLowerCase();
    if (lower.contains('oral')) return 'Oral';
    if (lower.contains('topical')) return 'Topical';
    if (lower.contains('intravenous')) return 'Intravenous';
    if (lower.contains('intramuscular')) return 'Intramuscular';
    if (lower.contains('subcutaneous')) return 'Subcutaneous';
    if (lower.contains('inhal')) return 'Inhaled';
    return '';
  }

  static String _genericName(
    String name,
    String strength,
    String form,
    String route,
  ) {
    var value = name;
    if (strength.isNotEmpty) value = value.replaceFirst(strength, '');
    if (route.isNotEmpty) {
      value = value.replaceAll(RegExp(route, caseSensitive: false), '');
    }
    if (form.isNotEmpty) {
      value = value.replaceAll(RegExp(form, caseSensitive: false), '');
    }
    return value
        .replaceAll(RegExp(r'\[[^\]]+\]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static String _titleCase(String value) => value
      .split(' ')
      .map(
        (part) => part.isEmpty
            ? part
            : '${part[0].toUpperCase()}${part.substring(1)}',
      )
      .join(' ');

  static String _firstString(Iterable<Object?> values) {
    for (final value in values) {
      if (value is String && value.trim().isNotEmpty) return value.trim();
    }
    return '';
  }

  static String _firstListString(Object? value) {
    if (value is Iterable) {
      return _firstString(value);
    }
    return value is String ? value.trim() : '';
  }

  static List<String> _stringList(Object? value) {
    if (value is Iterable) {
      return value
          .whereType<String>()
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList(growable: false);
    }
    return const [];
  }

  static Object? _valueAt(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      if (data.containsKey(key)) return data[key];
    }
    return null;
  }

  void dispose() => _client.close();
}
