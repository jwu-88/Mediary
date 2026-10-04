import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mediary/data/medication_catalog_client.dart';

void main() {
  for (final body in [
    {},
    {'drugGroup': 'unexpected'},
    {
      'drugGroup': {'conceptGroup': 'unexpected'},
    },
  ]) {
    test('malformed search payload remains retryable: $body', () async {
      var requests = 0;
      final client = RxNormMedicationCatalogClient(
        client: MockClient((request) async {
          if (request.url.path.endsWith('/version.json')) {
            return http.Response('{"version":"QA"}', 200);
          }
          requests++;
          return http.Response(jsonEncode(body), 200);
        }),
      );
      addTearDown(client.dispose);
      for (var i = 0; i < 2; i++) {
        await expectLater(
          client.search('ab'),
          throwsA(isA<MedicationCatalogException>()),
        );
      }
      expect(
        requests,
        2,
        reason: 'Malformed responses must not be cached as empty results.',
      );
    });
  }

  test('valid no-match search still returns an empty page', () async {
    final client = RxNormMedicationCatalogClient(
      client: MockClient((request) async {
        if (request.url.path.endsWith('/version.json')) {
          return http.Response('{"version":"QA"}', 200);
        }
        return http.Response('{"drugGroup":{"name":"ab"}}', 200);
      }),
    );
    addTearDown(client.dispose);
    expect((await client.search('ab')).items, isEmpty);
  });

  for (final body in [
    {},
    {'properties': {}},
    {
      'properties': {'name': ''},
    },
    {
      'properties': {'name': 123},
    },
  ]) {
    test(
      'incomplete details cannot invent a Medication record: $body',
      () async {
        final client = RxNormMedicationCatalogClient(
          client: MockClient((_) async => http.Response(jsonEncode(body), 200)),
        );
        addTearDown(client.dispose);
        await expectLater(
          client.getDetails('123'),
          throwsA(isA<MedicationCatalogException>()),
        );
      },
    );
  }
}
