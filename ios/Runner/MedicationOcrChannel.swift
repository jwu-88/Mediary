import Flutter
import CoreImage
import ImageIO
import UIKit
import Vision

/// ios ocr bridge backed by apple's vision framework.
///
/// vision runs locally on physical ios devices and apple silicon simulators.
final class MedicationOcrChannel: NSObject {
  private static let channelName = "com.mediary/medication_ocr"
  private static let renderingContext = CIContext(options: [.cacheIntermediates: false])
  private static let recognitionQueue = DispatchQueue(label: "com.mediary.ocr", qos: .userInitiated)

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

  static func recognize(imageData: Data, result: @escaping FlutterResult) {
    recognitionQueue.async {
      // image decoding and preprocessing must not block the flutter ui thread.
      guard let imageReference = decodedImageForRecognition(imageData) else {
        finish(
          result: result,
          value: FlutterError(
            code: "INVALID_IMAGE",
            message: "The selected image could not be decoded.",
            details: nil
          )
        )
        return
      }
      let variants = recognitionVariants(
        from: imageReference,
        orientation: .up
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

      // vision can return slightly different lines for each preprocessing
      // pass. keep the first occurrence of each line so the flutter review
      // screen receives useful text without duplicated ocr output.
      finish(result: result, value: mergeRecognizedText(recognizedTexts))
    }
  }

  static func decodedImageForRecognition(_ data: Data) -> CGImage? {
    let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
    guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions) else {
      return nil
    }
    // decode a bounded thumbnail directly instead of allocating the original
    // full-resolution photo. imageio also applies its stored orientation.
    let options = [
      kCGImageSourceCreateThumbnailFromImageAlways: true,
      kCGImageSourceCreateThumbnailWithTransform: true,
      kCGImageSourceThumbnailMaxPixelSize: 2400,
      kCGImageSourceShouldCacheImmediately: true,
    ] as CFDictionary
    return CGImageSourceCreateThumbnailAtIndex(source, 0, options)
  }

  private struct RecognitionVariant {
    let image: CGImage
    let orientation: CGImagePropertyOrientation
  }

  private static func recognitionVariants(
    from image: CGImage,
    orientation: CGImagePropertyOrientation
  ) -> [RecognitionVariant] {
    guard let normalizedImage = imageForRecognition(image) else { return [] }
    var variants = [RecognitionVariant(
      image: normalizedImage,
      orientation: orientation
    )]

    let source = CIImage(cgImage: normalizedImage)
      .oriented(forExifOrientation: Int32(orientation.rawValue))
    for (contrast, brightness) in [(1.25, 0.02), (1.55, 0.0)] {
      guard let filter = CIFilter(name: "CIColorControls") else { continue }
      filter.setValue(source, forKey: kCIInputImageKey)
      filter.setValue(0.0, forKey: kCIInputSaturationKey)
      filter.setValue(contrast, forKey: kCIInputContrastKey)
      filter.setValue(brightness, forKey: kCIInputBrightnessKey)
      guard
        let output = filter.outputImage,
        let processedImage = renderingContext.createCGImage(output, from: output.extent)
      else {
        continue
      }
      variants.append(RecognitionVariant(
        image: imageForRecognition(processedImage) ?? processedImage,
        orientation: .up
      ))
    }
    return variants
  }

  static func imageForRecognition(_ image: CGImage) -> CGImage? {
    let sourceDimension = CGFloat(max(image.width, image.height))
    let maxDimension: CGFloat = 2400
    let scale = min(2.5, maxDimension / sourceDimension)
    guard sourceDimension > maxDimension || scale > 1.01 else { return image }

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
      return nil
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

  private static func finish(result: @escaping FlutterResult, value: Any) {
    DispatchQueue.main.async {
      result(value)
    }
  }
}
