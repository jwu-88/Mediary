import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'medication_ocr_result.dart';

@JS('MediaryOcr.recognize')
external JSPromise<JSString> _recognizeMedicationText(JSString dataUrl);

@JS('MediaryOcr.recognizeWithEvidence')
external JSAny? get _evidenceRecognizer;

@JS('MediaryOcr.recognizeWithEvidence')
external JSPromise<JSString> _recognizeMedicationEvidence(JSString dataUrl);

Future<MedicationOcrEvidence> recognizeMedicationEvidence(
  Uint8List bytes, {
  String fileName = '',
}) async {
  try {
    // Older cached pages and preprocessing-baseline probes expose only the
    // plain-text bridge. Preserve their behavior without inventing recovery.
    if (!_evidenceRecognizer.isA<JSFunction>()) {
      return MedicationOcrEvidence(
        await recognizeMedicationText(bytes, fileName: fileName),
      );
    }
    final encoded = (await _recognizeMedicationEvidence(
      _medicationImageDataUrl(bytes, fileName).toJS,
    ).toDart).toDart;
    final data = jsonDecode(encoded);
    if (data is! Map<String, dynamic> || data['text'] is! String) {
      return const MedicationOcrEvidence('');
    }
    return MedicationOcrEvidence(
      data['text'] as String,
      recoveredUncertainText: data['recoveredUncertainText'] == true,
    );
  } catch (_) {
    return const MedicationOcrEvidence('');
  }
}

Future<String> recognizeMedicationText(
  Uint8List bytes, {
  String fileName = '',
}) async {
  try {
    return (await _recognizeMedicationText(
      _medicationImageDataUrl(bytes, fileName).toJS,
    ).toDart).toDart;
  } catch (_) {
    // The browser may block the external OCR worker or be offline. Returning
    // an empty result keeps the review flow safe and routes to manual review.
    // The JavaScript bridge also resets its worker after an error so the next
    // scan gets a clean initialization attempt.
    return '';
  }
}

String _medicationImageDataUrl(Uint8List bytes, String fileName) {
  final mimeType = fileName.toLowerCase().endsWith('.png')
      ? 'image/png'
      : fileName.toLowerCase().endsWith('.avif')
      ? 'image/avif'
      : 'image/jpeg';
  return 'data:$mimeType;base64,${base64Encode(bytes)}';
}
