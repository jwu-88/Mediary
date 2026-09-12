import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mediary/data/medication_catalog_client.dart';

void main() {
  test(
    'search parses, deduplicates, ranks, and caches RxNorm concepts',
    () async {
      var requests = 0;
      final client = RxNormMedicationCatalogClient(
        client: MockClient((request) async {
          requests++;
          if (request.url.path.endsWith('/version.json')) {
            return http.Response(jsonEncode({'version': '2026.09'}), 200);
          }
          return http.Response(
            jsonEncode({
              'drugGroup': {
                'conceptGroup': [
                  {
                    'tty': 'SBD',
                    'conceptProperties': [
                      {
                        'rxcui': '2',
                        'name': 'IBUPROFEN 200 MG Oral Tablet',
                        'synonym': 'Ibuprofen',
                      },
                    ],
                  },
                  {
                    'tty': 'SCD',
                    'conceptProperties': [
                      {
                        'rxcui': '1',
                        'name': 'Ibuprofen 200 MG Tablet',
                        'synonym': 'Ibuprofen',
                      },
                      {
                        'rxcui': '1',
                        'name': 'Ibuprofen 200 MG Tablet Pack',
                        'synonym': 'Ibuprofen',
                      },
                    ],
                  },
                ],
              },
            }),
            200,
          );
        }),
      );
      addTearDown(client.dispose);

      final first = await client.search('  ibuprofen  ');
      final second = await client.search('IBUPROFEN');

      expect(first.sourceVersion, '2026.09');
      expect(first.items.map((item) => item.rxcui).toSet(), {'1', '2'});
      expect(
        first.items.singleWhere((item) => item.rxcui == '1').form,
        'Tablet',
      );
      expect(identical(first, second), isTrue);
      expect(requests, 2); // RxNorm search plus one version request.
    },
  );

  test(
    'details merge openFDA label fields by RxCUI and cache the result',
    () async {
      var fdaRequests = 0;
      final client = RxNormMedicationCatalogClient(
        client: MockClient((request) async {
          if (request.url.path.endsWith('/version.json')) {
            return http.Response(jsonEncode({'rxnormVersion': 'v1'}), 200);
          }
          if (request.url.host == 'api.fda.gov') {
            fdaRequests++;
            return http.Response(
              jsonEncode({
                'results': [
                  {
                    'openfda': {
                      'generic_name': ['ibuprofen'],
                      'dosage_form': ['TABLET'],
                      'route': ['ORAL'],
                      'spl_set_id': ['abc'],
                    },
                    'warnings': ['Read the label.'],
                    'indications_and_usage': ['Pain relief.'],
                    'dosage_forms_and_strengths': ['200 mg tablet'],
                  },
                ],
              }),
              200,
            );
          }
          return http.Response(
            jsonEncode({
              'properties': {
                'rxcui': '123',
                'name': 'Ibuprofen 200 MG Tablet',
                'synonym': 'Ibuprofen',
                'tty': 'SCD',
              },
            }),
            200,
          );
        }),
      );
      addTearDown(client.dispose);

      final record = await client.getDetails('123');
      final cached = await client.getDetails('123');

      expect(record.genericName, 'ibuprofen');
      expect(record.form, 'TABLET');
      expect(record.route, 'ORAL');
      expect(record.warnings, ['Read the label.']);
      expect(record.labelUrl, contains('abc'));
      expect(identical(record, cached), isTrue);
      expect(fdaRequests, 1);
    },
  );

  test(
    'rate limits are surfaced and malformed responses fail clearly',
    () async {
      final limited = RxNormMedicationCatalogClient(
        client: MockClient((_) async => http.Response('', 429)),
      );
      addTearDown(limited.dispose);
      expect(
        () => limited.search('metformin'),
        throwsA(isA<MedicationCatalogRateLimitException>()),
      );

      final malformed = RxNormMedicationCatalogClient(
        client: MockClient((_) async => http.Response('not-json', 200)),
      );
      addTearDown(malformed.dispose);
      expect(
        () => malformed.search('metformin'),
        throwsA(isA<MedicationCatalogException>()),
      );
    },
  );
}
