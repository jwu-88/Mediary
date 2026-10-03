package com.example.flutter_application

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.ColorMatrix
import android.graphics.ColorMatrixColorFilter
import android.graphics.Paint
import com.google.android.gms.tasks.OnCompleteListener
import com.google.android.gms.tasks.Tasks
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

            val variants = createRecognitionVariants(bitmap)
            val recognizer = TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)
            val tasks = variants.map { variant ->
                recognizer.process(InputImage.fromBitmap(variant, 0))
                    .continueWith { task ->
                        if (task.isSuccessful) task.result?.text.orEmpty() else ""
                    }
            }
            Tasks.whenAllSuccess<String>(tasks)
                .addOnSuccessListener { texts ->
                    result.success(mergeRecognizedText(texts))
                }
                .addOnFailureListener { error ->
                    result.error("OCR_FAILED", error.message ?: "Text recognition failed.", null)
                }
                .addOnCompleteListener(OnCompleteListener {
                    recognizer.close()
                    variants
                        .filter { it !== bitmap && !it.isRecycled }
                        .forEach { it.recycle() }
                    if (!bitmap.isRecycled) bitmap.recycle()
                })
        }
    }

    private fun createRecognitionVariants(source: Bitmap): List<Bitmap> {
        val sourceDimension = maxOf(source.width, source.height).toFloat()
        val scale = minOf(2.5f, maxOf(1f, 2400f / sourceDimension))
        val width = maxOf(1, (source.width * scale).toInt())
        val height = maxOf(1, (source.height * scale).toInt())
        val resized = Bitmap.createScaledBitmap(source, width, height, true)

        val base = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        Canvas(base).apply {
            drawColor(Color.WHITE)
            drawBitmap(resized, 0f, 0f, Paint(Paint.ANTI_ALIAS_FLAG))
        }
        if (resized !== source && !resized.isRecycled) resized.recycle()

        val grayscale = applyColorMatrix(
            base,
            ColorMatrix().apply {
                // Grayscale luminance coefficients with a 1.35 contrast
                // boost around mid-gray. Keeping this as one matrix avoids
                // relying on ColorMatrix APIs that are unavailable on older
                // Android SDK surfaces.
                set(
                    floatArrayOf(
                        0.40365f, 0.79245f, 0.1539f, 0f, -44.8f,
                        0.40365f, 0.79245f, 0.1539f, 0f, -44.8f,
                        0.40365f, 0.79245f, 0.1539f, 0f, -44.8f,
                        0f, 0f, 0f, 1f, 0f,
                    ),
                )
            },
        )
        val threshold = thresholdBitmap(grayscale)
        return listOf(base, grayscale, threshold)
    }

    private fun applyColorMatrix(source: Bitmap, matrix: ColorMatrix): Bitmap {
        val output = Bitmap.createBitmap(
            source.width,
            source.height,
            Bitmap.Config.ARGB_8888,
        )
        Canvas(output).drawBitmap(
            source,
            0f,
            0f,
            Paint(Paint.ANTI_ALIAS_FLAG).apply {
                colorFilter = ColorMatrixColorFilter(matrix)
            },
        )
        return output
    }

    private fun thresholdBitmap(source: Bitmap): Bitmap {
        val output = Bitmap.createBitmap(
            source.width,
            source.height,
            Bitmap.Config.ARGB_8888,
        )
        val pixels = IntArray(source.width * source.height)
        source.getPixels(pixels, 0, source.width, 0, 0, source.width, source.height)
        for (index in pixels.indices) {
            val color = pixels[index]
            val luminance = (
                Color.red(color) * 0.299f +
                    Color.green(color) * 0.587f +
                    Color.blue(color) * 0.114f
                ).toInt()
            pixels[index] = if (luminance > 175) Color.WHITE else Color.BLACK
        }
        output.setPixels(pixels, 0, source.width, 0, 0, source.width, source.height)
        return output
    }

    private fun mergeRecognizedText(texts: List<String>): String {
        val seen = linkedSetOf<String>()
        return texts
            .flatMap { it.lines() }
            .map { it.trim() }
            .filter { it.isNotEmpty() }
            .filter { seen.add(it.lowercase()) }
            .joinToString("\n")
    }
}
