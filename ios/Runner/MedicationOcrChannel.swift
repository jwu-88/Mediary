import Flutter
import CoreImage
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
      let orientation = cgImagePropertyOrientation(for: image.imageOrientation)
      let variants = recognitionVariants(
        from: imageReference,
        orientation: orientation
      )
      var recognizedTexts = [String]()

      for variant in variants {
        if let text = recognizeText(
          from: variant.image,
          orientation: variant.orientation
        ), !text.isEmpty {
          recognizedTexts.append(text)
        }
      }

      // Vision can return slightly different lines for each preprocessing
      // pass. Keep the first occurrence of each line so the Flutter review
      // screen receives useful text without duplicated OCR output.
      finish(result: result, value: mergeRecognizedText(recognizedTexts))
    }
  }

  private struct RecognitionVariant {
    let image: CGImage
    let orientation: CGImagePropertyOrientation
  }

  private static func recognitionVariants(
    from image: CGImage,
    orientation: CGImagePropertyOrientation
  ) -> [RecognitionVariant] {
    let normalizedImage = upscaledImage(image) ?? image
    var variants = [RecognitionVariant(
      image: normalizedImage,
      orientation: orientation
    )]

    let source = CIImage(cgImage: normalizedImage)
      .oriented(forExifOrientation: Int32(orientation.rawValue))
    let context = CIContext(options: nil)
    for (contrast, brightness) in [(1.25, 0.02), (1.55, 0.0)] {
      guard let filter = CIFilter(name: "CIColorControls") else { continue }
      filter.setValue(source, forKey: kCIInputImageKey)
      filter.setValue(0.0, forKey: kCIInputSaturationKey)
      filter.setValue(contrast, forKey: kCIInputContrastKey)
      filter.setValue(brightness, forKey: kCIInputBrightnessKey)
      guard
        let output = filter.outputImage,
        let processedImage = context.createCGImage(output, from: output.extent)
      else {
        continue
      }
      variants.append(RecognitionVariant(
        image: upscaledImage(processedImage) ?? processedImage,
        orientation: .up
      ))
    }
    return variants
  }

  private static func upscaledImage(_ image: CGImage) -> CGImage? {
    let sourceDimension = CGFloat(max(image.width, image.height))
    let scale = min(2.5, max(1.0, 2400.0 / sourceDimension))
    guard scale > 1.01 else { return image }

    let width = max(1, Int(CGFloat(image.width) * scale))
    let height = max(1, Int(CGFloat(image.height) * scale))
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    guard let context = CGContext(
      data: nil,
      width: width,
      height: height,
      bitsPerComponent: 8,
      bytesPerRow: width * 4,
      space: colorSpace,
      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
      return image
    }

    context.interpolationQuality = .high
    context.setFillColor(UIColor.white.cgColor)
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
    return context.makeImage()
  }

  private static func recognizeText(
    from image: CGImage,
    orientation: CGImagePropertyOrientation
  ) -> String? {
    var text = ""
    let request = VNRecognizeTextRequest { request, _ in
      let observations = request.results as? [VNRecognizedTextObservation] ?? []
      text = observations.compactMap { observation in
        observation.topCandidates(1).first?.string
      }.joined(separator: "\n")
    }
    request.recognitionLevel = .accurate
    request.usesLanguageCorrection = true
    request.recognitionLanguages = ["en-US"]
    request.minimumTextHeight = 0.008

    do {
      let handler = VNImageRequestHandler(
        cgImage: image,
        orientation: orientation,
        options: [:]
      )
      try handler.perform([request])
      return text.trimmingCharacters(in: .whitespacesAndNewlines)
    } catch {
      return nil
    }
  }

  private static func mergeRecognizedText(_ texts: [String]) -> String {
    var seen = Set<String>()
    return texts
      .flatMap { $0.components(separatedBy: .newlines) }
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }
      .filter { seen.insert($0.lowercased()).inserted }
      .joined(separator: "\n")
  }

  private static func cgImagePropertyOrientation(
    for orientation: UIImage.Orientation
  ) -> CGImagePropertyOrientation {
    switch orientation {
    case .up: return .up
    case .down: return .down
    case .left: return .left
    case .right: return .right
    case .upMirrored: return .upMirrored
    case .downMirrored: return .downMirrored
    case .leftMirrored: return .leftMirrored
    case .rightMirrored: return .rightMirrored
    @unknown default: return .up
    }
  }

  private static func finish(result: @escaping FlutterResult, value: Any) {
    DispatchQueue.main.async {
      result(value)
    }
  }
}
