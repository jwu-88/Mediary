import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mediary/data/medication_catalog_client.dart';

void main() {
  test('short or blank searches do not call RxNorm', () async {
    var requestCount = 0;
    final client = RxNormMedicationCatalogClient(
      client: MockClient((_) async {
        requestCount++;
        return http.Response('{}', 200);
      }),
    );
    addTearDown(client.dispose);

    expect((await client.search('')).items, isEmpty);
    expect((await client.search('  ')).items, isEmpty);
    expect((await client.search('x')).items, isEmpty);
    expect(requestCount, 0);
  });

  test(
    'empty RxNorm groups produce an empty page with source version',
    () async {
      final client = RxNormMedicationCatalogClient(
        client: MockClient((request) async {
          if (request.url.path.endsWith('/version.json')) {
            return http.Response(jsonEncode({'rxnormVersion': '2026AB'}), 200);
          }
          return http.Response(
            jsonEncode({
              'drugGroup': {'conceptGroup': []},
            }),
            200,
          );
        }),
      );
      addTearDown(client.dispose);

      final page = await client.search('unknown medicine');

      expect(page.items, isEmpty);
      expect(page.sourceVersion, '2026AB');
    },
  );

  test('details remain usable when openFDA has no matching label', () async {
    final client = RxNormMedicationCatalogClient(
      client: MockClient((request) async {
        if (request.url.host == 'api.fda.gov') {
          return http.Response('{}', 404);
        }
        if (request.url.path.endsWith('/version.json')) {
          return http.Response(jsonEncode({'version': 'v2026'}), 200);
        }
        return http.Response(
          jsonEncode({
            'properties': {
              'rxcui': '111',
              'name': 'Metformin 500 MG Oral Tablet',
              'synonym': 'Metformin',
              'tty': 'SCD',
            },
          }),
          200,
        );
      }),
    );
    addTearDown(client.dispose);

    final record = await client.getDetails('111');

    expect(record.rxcui, '111');
    expect(record.name, 'Metformin 500 MG Oral Tablet');
    expect(record.sourceVersion, 'v2026');
    expect(record.labelUrl, isNull);
    expect(record.warnings, isEmpty);
  });

  test('malformed openFDA enrichment falls back to RxNorm details', () async {
    final client = RxNormMedicationCatalogClient(
      client: MockClient((request) async {
        if (request.url.host == 'api.fda.gov') {
          return http.Response('not-json', 200);
        }
        if (request.url.path.endsWith('/version.json')) {
          return http.Response(jsonEncode({'version': 'v1'}), 200);
        }
        return http.Response(
          jsonEncode({
            'properties': {
              'name': 'Cetirizine 10 MG Oral Tablet',
              'synonym': 'Cetirizine',
              'tty': 'SCD',
            },
          }),
          200,
        );
      }),
    );
    addTearDown(client.dispose);

    final record = await client.getDetails('999');

    expect(record.name, 'Cetirizine 10 MG Oral Tablet');
    expect(record.genericName, contains('Cetirizine'));
    expect(record.warnings, isEmpty);
  });

  test('openFDA rate limits are surfaced for detail enrichment', () async {
    final client = RxNormMedicationCatalogClient(
      client: MockClient((request) async {
        if (request.url.host == 'api.fda.gov') {
          return http.Response('{}', 429);
        }
        if (request.url.path.endsWith('/version.json')) {
          return http.Response(jsonEncode({'version': 'v1'}), 200);
        }
        return http.Response(
          jsonEncode({
            'properties': {'name': 'Ibuprofen 200 MG Tablet'},
          }),
          200,
        );
      }),
    );
    addTearDown(client.dispose);

    await expectLater(
      client.getDetails('5640'),
      throwsA(isA<MedicationCatalogRateLimitException>()),
    );
  });

  test('network timeouts become user-facing catalog errors', () async {
    final client = RxNormMedicationCatalogClient(
      client: MockClient((_) async {
        throw TimeoutException('simulated timeout');
      }),
    );
    addTearDown(client.dispose);

    await expectLater(
      client.search('ibuprofen'),
      throwsA(
        allOf(
          isA<MedicationCatalogException>(),
          predicate<MedicationCatalogException>(
            (error) => error.message.toLowerCase().contains('timed out'),
          ),
        ),
      ),
    );
  });

  test('non-success RxNorm responses retain their status code', () async {
    final client = RxNormMedicationCatalogClient(
      client: MockClient((_) async => http.Response('server error', 503)),
    );
    addTearDown(client.dispose);

    await expectLater(
      client.search('ibuprofen'),
      throwsA(
        predicate<MedicationCatalogException>(
          (error) => error.statusCode == 503,
        ),
      ),
    );
  });
}
