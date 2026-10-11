import CoreGraphics
import ImageIO
import UIKit
import XCTest
@testable import Runner

final class RunnerTests: XCTestCase {
  func testVisionRecognizesLabelAndReturnsOnMainThread() throws {
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    let image = UIGraphicsImageRenderer(size: CGSize(width: 800, height: 300), format: format).image { context in
      UIColor.white.setFill()
      context.fill(CGRect(x: 0, y: 0, width: 800, height: 300))
      ("Ibuprofen 200 mg" as NSString).draw(
        at: CGPoint(x: 40, y: 90),
        withAttributes: [.font: UIFont.systemFont(ofSize: 64), .foregroundColor: UIColor.black]
      )
    }
    let data = try XCTUnwrap(image.pngData())
    let complete = expectation(description: "local vision recognition completes")
    MedicationOcrChannel.recognize(imageData: data) { result in
      XCTAssertTrue(Thread.isMainThread)
      XCTAssertTrue((result as? String ?? "").lowercased().contains("ibuprofen"))
      complete.fulfill()
    }
    wait(for: [complete], timeout: 30)
  }

  func testLargeEncodedPhotoDecodesWithinMemoryLimit() throws {
    let source = try image(width: 3000, height: 2000)
    let encoded = try encodedImage(source)
    let decoded = try XCTUnwrap(MedicationOcrChannel.decodedImageForRecognition(encoded))
    XCTAssertEqual(decoded.width, 2400)
    XCTAssertEqual(decoded.height, 1600)
  }

  func testStoredPhotoOrientationIsAppliedBeforeRecognition() throws {
    let source = try image(width: 400, height: 200)
    let encoded = try encodedImage(source, orientation: 6)
    let decoded = try XCTUnwrap(MedicationOcrChannel.decodedImageForRecognition(encoded))
    XCTAssertEqual(decoded.width, 200)
    XCTAssertEqual(decoded.height, 400)
  }

  func testInvalidPhotoReturnsNoImage() {
    XCTAssertNil(MedicationOcrChannel.decodedImageForRecognition(Data([1, 2, 3])))
  }

  func testLargePhotoIsDownscaledWithinRecognitionMemoryLimit() throws {
    let source = try image(width: 3000, height: 2000)
    let resized = try XCTUnwrap(MedicationOcrChannel.imageForRecognition(source))
    XCTAssertEqual(resized.width, 2400)
    XCTAssertEqual(resized.height, 1600)
  }

  func testPortraitPhotoKeepsItsAspectRatio() throws {
    let source = try image(width: 1000, height: 3000)
    let resized = try XCTUnwrap(MedicationOcrChannel.imageForRecognition(source))
    XCTAssertEqual(resized.width, 800)
    XCTAssertEqual(resized.height, 2400)
  }

  func testSmallLabelIsUpscaledForReadableText() throws {
    let source = try image(width: 400, height: 200)
    let resized = try XCTUnwrap(MedicationOcrChannel.imageForRecognition(source))
    XCTAssertEqual(resized.width, 1000)
    XCTAssertEqual(resized.height, 500)
  }

  func testPhotoJustAboveTheLimitStillDownscales() throws {
    let source = try image(width: 2401, height: 1600)
    let resized = try XCTUnwrap(MedicationOcrChannel.imageForRecognition(source))
    XCTAssertEqual(resized.width, 2400)
    XCTAssertLessThanOrEqual(resized.height, 1600)
  }

  private func image(width: Int, height: Int) throws -> CGImage {
    let context = try XCTUnwrap(CGContext(
      data: nil,
      width: width,
      height: height,
      bitsPerComponent: 8,
      bytesPerRow: width * 4,
      space: CGColorSpaceCreateDeviceRGB(),
      bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
    ))
    return try XCTUnwrap(context.makeImage())
  }

  private func encodedImage(_ image: CGImage, orientation: Int = 1) throws -> Data {
    let data = NSMutableData()
    let destination = try XCTUnwrap(CGImageDestinationCreateWithData(
      data, "public.jpeg" as CFString, 1, nil
    ))
    CGImageDestinationAddImage(destination, image, [kCGImagePropertyOrientation: orientation] as CFDictionary)
    XCTAssertTrue(CGImageDestinationFinalize(destination))
    return data as Data
  }
}
