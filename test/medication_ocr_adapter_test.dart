@TestOn('vm')
library;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediary/ocr/medication_ocr.dart' as ocr;
import 'package:mediary/ocr/medication_ocr_stub.dart' as stub;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.mediary/medication_ocr');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test(
    'native evidence preserves label text and original image arguments',
    () async {
      final bytes = Uint8List.fromList([1, 2, 3]);
      MethodCall? request;
      messenger.setMockMethodCallHandler(channel, (call) async {
        request = call;
        return 'Benadryl\nDiphenhydramine HCl 25 mg';
      });

      final evidence = await ocr.recognizeMedicationEvidence(
        bytes,
        fileName: 'camera.png',
      );

      expect(evidence.text, 'Benadryl\nDiphenhydramine HCl 25 mg');
      expect(evidence.recoveredUncertainText, isFalse);
      expect(request?.method, 'recognize');
      expect((request?.arguments as Map)['bytes'], orderedEquals(bytes));
      expect((request?.arguments as Map)['fileName'], 'camera.png');
    },
  );

  test('native missing text remains empty without recovery evidence', () async {
    messenger.setMockMethodCallHandler(channel, (_) async => null);
    final evidence = await ocr.recognizeMedicationEvidence(Uint8List(1));
    expect(evidence.text, isEmpty);
    expect(evidence.recoveredUncertainText, isFalse);
  });

  test(
    'native adapter keeps platform failures visible to the detector',
    () async {
      messenger.setMockMethodCallHandler(channel, (_) async {
        throw PlatformException(code: 'ocr-unavailable');
      });
      await expectLater(
        ocr.recognizeMedicationEvidence(Uint8List(1)),
        throwsA(isA<PlatformException>()),
      );
    },
  );

  test(
    'unsupported platform reports empty text and no recovery evidence',
    () async {
      final evidence = await stub.recognizeMedicationEvidence(Uint8List(1));
      expect(evidence.text, isEmpty);
      expect(evidence.recoveredUncertainText, isFalse);
    },
  );
}
