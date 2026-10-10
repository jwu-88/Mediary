@TestOn('browser')
library;

import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mediary/ocr/medication_ocr.dart' as ocr;

@JS('MediaryOcr')
external JSObject? get _bridge;

@JS('MediaryOcr')
external set _bridge(JSObject? value);

void main() {
  JSObject? originalBridge;
  setUp(() => originalBridge = _bridge);
  tearDown(() => _bridge = originalBridge);

  test(
    'web evidence preserves recovery flag and sends PNG image bytes',
    () async {
      String? imageDataUrl;
      _bridge =
          {
                'recognizeWithEvidence': ((JSString url) {
                  imageDataUrl = url.toDart;
                  return Future<JSString>.value(
                    jsonEncode({
                      'text': 'Excedrin Migraine',
                      'recoveredUncertainText': true,
                    }).toJS,
                  ).toJS;
                }).toJS,
              }.jsify()
              as JSObject;

      final evidence = await ocr.recognizeMedicationEvidence(
        Uint8List.fromList([1, 2, 3]),
        fileName: 'camera.PNG',
      );
      expect(imageDataUrl, 'data:image/png;base64,AQID');
      expect(evidence.text, 'Excedrin Migraine');
      expect(evidence.recoveredUncertainText, isTrue);
    },
  );

  test(
    'cached plain-text bridge falls back without claiming recovery',
    () async {
      _bridge =
          {
                'recognize': ((JSString _) => Future<JSString>.value(
                  'Aleve'.toJS,
                ).toJS).toJS,
              }.jsify()
              as JSObject;

      final evidence = await ocr.recognizeMedicationEvidence(Uint8List(1));
      expect(evidence.text, 'Aleve');
      expect(evidence.recoveredUncertainText, isFalse);
      expect(await ocr.recognizeMedicationText(Uint8List(1)), 'Aleve');
    },
  );

  test(
    'malformed evidence fails safely instead of dropping its provenance',
    () async {
      _bridge =
          {
                'recognizeWithEvidence': ((
                  JSString _,
                ) => Future<JSString>.value('not JSON'.toJS).toJS).toJS,
              }.jsify()
              as JSObject;

      final evidence = await ocr.recognizeMedicationEvidence(Uint8List(1));
      expect(evidence.text, isEmpty);
      expect(evidence.recoveredUncertainText, isFalse);
    },
  );

  test('only a boolean recovery flag is accepted', () async {
    _bridge =
        {
              'recognizeWithEvidence': ((JSString _) => Future<JSString>.value(
                '{"text":"Benadryl","recoveredUncertainText":"true"}'.toJS,
              ).toJS).toJS,
            }.jsify()
            as JSObject;

    final evidence = await ocr.recognizeMedicationEvidence(Uint8List(1));
    expect(evidence.text, 'Benadryl');
    expect(evidence.recoveredUncertainText, isFalse);
  });

  test('missing browser bridge returns empty evidence', () async {
    _bridge = null;
    final evidence = await ocr.recognizeMedicationEvidence(Uint8List(1));
    expect(evidence.text, isEmpty);
    expect(evidence.recoveredUncertainText, isFalse);
  });
}
