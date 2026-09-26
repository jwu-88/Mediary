import 'dart:io';
import 'dart:typed_data';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

/// Uses the native ML Kit text recognizer without exposing dart:io to web
/// builds. The temporary file is deleted immediately after recognition.
Future<String> recognizeMedicationText(
  Uint8List bytes, {
  String fileName = '',
}) async {
  final temporaryDirectory = await getTemporaryDirectory();
  final extension = path.extension(fileName).toLowerCase();
  final safeExtension = extension == '.png' || extension == '.webp'
      ? extension
      : '.jpg';
  final file = File(
    path.join(
      temporaryDirectory.path,
      'mediary-medication-${DateTime.now().microsecondsSinceEpoch}$safeExtension',
    ),
  );
  final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
  try {
    await file.writeAsBytes(bytes, flush: true);
    final result = await recognizer.processImage(
      InputImage.fromFilePath(file.path),
    );
    return result.text;
  } finally {
    await recognizer.close();
    if (await file.exists()) {
      await file.delete();
    }
  }
}
