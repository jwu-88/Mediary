export 'medication_ocr_stub.dart'
    if (dart.library.io) 'medication_ocr_native.dart'
    if (dart.library.js_interop) 'medication_ocr_web.dart';
