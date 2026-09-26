package com.example.flutter_application

import android.graphics.BitmapFactory
import com.google.android.gms.tasks.OnCompleteListener
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions

class MainActivity : FlutterActivity() {
    private val ocrChannelName = "com.mediary/medication_ocr"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            ocrChannelName,
        ).setMethodCallHandler { call, result ->
            if (call.method != "recognize") {
                result.notImplemented()
                return@setMethodCallHandler
            }

            val bytes = call.argument<ByteArray>("bytes")
            if (bytes == null || bytes.isEmpty()) {
                result.error("EMPTY_IMAGE", "The image did not contain any bytes.", null)
                return@setMethodCallHandler
            }

            val bitmap = BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
            if (bitmap == null) {
                result.error("INVALID_IMAGE", "The selected image could not be decoded.", null)
                return@setMethodCallHandler
            }

            val recognizer = TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)
            recognizer.process(InputImage.fromBitmap(bitmap, 0))
                .addOnSuccessListener { visionText -> result.success(visionText.text) }
                .addOnFailureListener { error ->
                    result.error("OCR_FAILED", error.message ?: "Text recognition failed.", null)
                }
                .addOnCompleteListener(OnCompleteListener { recognizer.close() })
        }
    }
}
