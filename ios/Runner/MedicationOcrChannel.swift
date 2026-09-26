import Flutter
import ImageIO
import UIKit
import Vision

/// iOS OCR bridge backed by Apple's Vision framework.
///
/// Vision is available on both physical iOS devices and Apple Silicon
/// simulators, so the app does not need to link Google ML Kit's incompatible
/// simulator-only binaries for this feature.
final class MedicationOcrChannel: NSObject {
  private static let channelName = "com.mediary/medication_ocr"

  static func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      guard call.method == "recognize" else {
        result(FlutterMethodNotImplemented)
        return
      }

      guard
        let arguments = call.arguments as? [String: Any],
        let imageData = (arguments["bytes"] as? FlutterStandardTypedData)?.data,
        !imageData.isEmpty
      else {
        result(
          FlutterError(
            code: "EMPTY_IMAGE",
            message: "The image did not contain any bytes.",
            details: nil
          )
        )
        return
      }

      recognize(imageData: imageData, result: result)
    }
  }

  private static func recognize(imageData: Data, result: @escaping FlutterResult) {
    guard let image = UIImage(data: imageData), let imageReference = image.cgImage else {
      result(
        FlutterError(
          code: "INVALID_IMAGE",
          message: "The selected image could not be decoded.",
          details: nil
        )
      )
      return
    }

    DispatchQueue.global(qos: .userInitiated).async {
      let request = VNRecognizeTextRequest { request, error in
        if let error {
          finish(result: result, value: FlutterError(
            code: "OCR_FAILED",
            message: error.localizedDescription,
            details: nil
          ))
          return
        }

        let observations = request.results as? [VNRecognizedTextObservation] ?? []
        let text = observations.compactMap { observation in
          observation.topCandidates(1).first?.string
        }.joined(separator: "\n")
        finish(result: result, value: text)
      }
      request.recognitionLevel = .accurate
      request.usesLanguageCorrection = true
      request.recognitionLanguages = ["en-US"]

      do {
        let handler = VNImageRequestHandler(
          cgImage: imageReference,
          orientation: .up,
          options: [:]
        )
        try handler.perform([request])
      } catch {
        finish(result: result, value: FlutterError(
          code: "OCR_FAILED",
          message: error.localizedDescription,
          details: nil
        ))
      }
    }
  }

  private static func finish(result: @escaping FlutterResult, value: Any) {
    DispatchQueue.main.async {
      result(value)
    }
  }
}
