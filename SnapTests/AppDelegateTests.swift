import XCTest
@testable import Snap

final class AppDelegateTests: XCTestCase {

    func testHandleCapturedImageCachesLastImageWithoutUI() {
        let delegate = AppDelegate()
        let image = createTestImage(width: 42, height: 24)

        delegate.handleCapturedImage(image, showUI: false)

        XCTAssertEqual(OutputManager.lastCapturedImage?.width, 42)
        XCTAssertEqual(OutputManager.lastCapturedImage?.height, 24)
    }

    // MARK: - Helpers

    private func createTestImage(width: Int, height: Int) -> CGImage {
        let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        context.setFillColor(NSColor.blue.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()!
    }
}
