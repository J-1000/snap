import XCTest
@testable import Snap

final class AppDelegateTests: XCTestCase {

    func testHandleCapturedImageCachesLastImageWithoutUI() {
        let delegate = AppDelegate()
        let image = createTestImage(width: 42, height: 24)

        delegate.handleCapturedImage(image, scaleFactor: 2.0, showUI: false)

        XCTAssertEqual(OutputManager.lastCapturedImage?.width, 42)
        XCTAssertEqual(OutputManager.lastCapturedImage?.height, 24)
        XCTAssertEqual(OutputManager.lastCapturedScaleFactor, 2.0)
    }

    func testHandleCapturedImageAutoSavesWhenEnabled() {
        let delegate = AppDelegate()
        let image = createTestImage(width: 10, height: 10)
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)

        let prefs = PreferencesManager.shared
        let originalSaveDirectory = prefs.saveDirectory
        let originalAutoSave = prefs.autoSaveAfterCapture
        let originalCopy = prefs.copyToClipboardAfterCapture
        let originalFormat = prefs.imageFormat
        defer {
            prefs.saveDirectory = originalSaveDirectory
            prefs.autoSaveAfterCapture = originalAutoSave
            prefs.copyToClipboardAfterCapture = originalCopy
            prefs.imageFormat = originalFormat
            try? FileManager.default.removeItem(at: tempDir)
        }

        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        prefs.saveDirectory = tempDir
        prefs.autoSaveAfterCapture = true
        prefs.copyToClipboardAfterCapture = false
        prefs.imageFormat = "png"

        delegate.handleCapturedImage(image, scaleFactor: 1.0, showUI: false)

        let contents = (try? FileManager.default.contentsOfDirectory(atPath: tempDir.path)) ?? []
        XCTAssertFalse(contents.isEmpty)
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
