import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

@JS('MediaryOcr.recognize')
external JSPromise<JSString> _recognizeMedicationText(JSString dataUrl);

Future<String> recognizeMedicationText(
  Uint8List bytes, {
  String fileName = '',
}) async {
  final mimeType = fileName.toLowerCase().endsWith('.png')
      ? 'image/png'
      : fileName.toLowerCase().endsWith('.avif')
      ? 'image/avif'
      : 'image/jpeg';
  final dataUrl = 'data:$mimeType;base64,${base64Encode(bytes)}';
  try {
    return (await _recognizeMedicationText(dataUrl.toJS).toDart).toDart;
  } catch (_) {
    // The browser may block the external OCR worker or be offline. Returning
    // an empty result keeps the review flow safe and routes to manual review.
    // The JavaScript bridge also resets its worker after an error so the next
    // scan gets a clean initialization attempt.
    return '';
  }
}
