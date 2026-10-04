import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mediary/medication_scan.dart';
import 'package:mediary/web_camera.dart';

class _CameraPicker extends ImagePicker {
  _CameraPicker({this.file, this.error});
  final XFile? file;
  final Object? error;
  ImageSource? requestedSource;
  bool? requestedMetadata;

  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async {
    requestedSource = source;
    requestedMetadata = requestFullMetadata;
    if (error != null) throw error!;
    return file;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('native capture passes the confirmed camera bytes to OCR', () async {
    final bytes = Uint8List.fromList([1, 2, 3, 4]);
    final picker = _CameraPicker(
      file: XFile.fromData(bytes, path: 'camera.jpg'),
    );
    final image = await captureMedicationPhoto(picker: picker);
    expect(picker.requestedSource, ImageSource.camera);
    expect(picker.requestedMetadata, false);
    expect(image!.bytes, orderedEquals(bytes));
    expect(image.fileName, 'camera.jpg');
  });

  test('cancelled native capture returns no image', () async {
    expect(await captureMedicationPhoto(picker: _CameraPicker()), isNull);
  });

  test(
    'native capture preserves permission failures for shell feedback',
    () async {
      final error = PlatformException(code: 'camera_access_denied');
      await expectLater(
        captureMedicationPhoto(picker: _CameraPicker(error: error)),
        throwsA(same(error)),
      );
    },
  );

  for (final bytes in [null, Uint8List(0)]) {
    test(
      'missing photo data does not identify a sample medication ($bytes)',
      () async {
        final result = await const MedicationOcrDetector().detect(
          MedicationScanRequest(
            source: MedicationScanSource.camera,
            imageUrl: '',
            imageBytes: bytes,
          ),
        );
        expect(result.hasError, isTrue);
        expect(result.confidence, 0);
        expect(result.detectedMedicationName, isEmpty);
        expect(result.extractedText, isEmpty);
      },
    );
  }

  test('empty selected image does not identify Amoxicillin', () async {
    final result = await const MedicationOcrDetector().detect(
      MedicationScanRequest.fromImage(
        imageBytes: Uint8List(0),
        fileName: 'empty.jpg',
      ),
    );
    expect(result.hasError, isTrue);
    expect(result.detectedMedicationName, isEmpty);
    expect(result.confidence, 0);
  });

  test('only an explicit sample request can use the demo fixture', () async {
    final result = await const MedicationOcrDetector().detect(
      const MedicationScanRequest.sample(),
    );
    expect(result.hasError, isFalse);
    expect(result.detectedMedicationName, 'Amoxicillin');
  });

  test('native browser capture stub has no camera frame', () async {
    expect(await captureWebCameraFrame(), isNull);
  });
}
