import XCTest
@testable import Snap

@MainActor
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

    func testEditorScaleKeepsOversizedCaptureAndToolbarsVisible() {
        let image = createTestImage(width: 3000, height: 2000)
        let available = NSSize(width: 1200, height: 800)

        let scale = AnnotationWindow.fittedScaleFactor(
            for: image,
            captureScaleFactor: 2,
            availableSize: available
        )
        let editorSize = AnnotationWindow.contentSize(for: image, scaleFactor: scale)

        XCTAssertGreaterThan(scale, 2)
        XCTAssertLessThanOrEqual(editorSize.width, available.width + 0.001)
        XCTAssertLessThanOrEqual(editorSize.height, available.height + 0.001)
    }

    func testEditorScaleDoesNotEnlargeCaptureThatAlreadyFits() {
        let image = createTestImage(width: 800, height: 600)

        let scale = AnnotationWindow.fittedScaleFactor(
            for: image,
            captureScaleFactor: 2,
            availableSize: NSSize(width: 1200, height: 900)
        )

        XCTAssertEqual(scale, 2)
    }

    func testSmallCaptureKeepsAllEditorControlsVisible() {
        let image = createTestImage(width: 100, height: 80)

        let size = AnnotationWindow.contentSize(for: image, scaleFactor: 2)

        XCTAssertGreaterThanOrEqual(size.width, ActionToolbar.minimumWidth)
        XCTAssertGreaterThanOrEqual(
            size.height,
            EditingToolbar.minimumHeight + ActionToolbar.height
        )
    }

    func testAnnotationFontPointsConvertToRetinaPixels() {
        XCTAssertEqual(AnnotationView.imageFontSize(pointSize: 16, captureScaleFactor: 2), 32)
        XCTAssertEqual(AnnotationView.imageFontSize(pointSize: 16, captureScaleFactor: 1), 16)
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

@MainActor
final class CaptureEngineTests: XCTestCase {

    func testRepeatAreaClampKeepsRegionInsideChangedDisplay() {
        let rect = NSRect(x: 900, y: 700, width: 400, height: 300)
        let screen = NSRect(x: 0, y: 0, width: 1000, height: 800)

        let clamped = CaptureEngine.clampedCaptureRect(rect, to: screen)

        XCTAssertEqual(clamped, NSRect(x: 600, y: 500, width: 400, height: 300))
    }

    func testRepeatAreaClampShrinksRegionLargerThanDisplay() {
        let rect = NSRect(x: -100, y: -100, width: 1600, height: 1200)
        let screen = NSRect(x: 20, y: 30, width: 1000, height: 800)

        let clamped = CaptureEngine.clampedCaptureRect(rect, to: screen)

        XCTAssertEqual(clamped, screen)
    }

    func testFullScreenCaptureRejectsOverlapAndResetsAfterSuccess() async {
        let image = createTestImage(width: 12, height: 8)
        let started = expectation(description: "capture started")
        let captured = expectation(description: "capture completed")
        var invocationCount = 0
        var pending: CheckedContinuation<CGImage, Never>?
        let engine = CaptureEngine(fullScreenCapture: { _ in
            invocationCount += 1
            started.fulfill()
            return await withCheckedContinuation { pending = $0 }
        })
        engine.onImageCaptured = { _, _, _ in captured.fulfill() }

        engine.captureFullScreen(NSScreen.main!)
        await fulfillment(of: [started])
        XCTAssertTrue(engine.isActive)

        engine.captureFullScreen(NSScreen.main!)
        XCTAssertEqual(invocationCount, 1)

        pending?.resume(returning: image)
        await fulfillment(of: [captured])
        XCTAssertFalse(engine.isActive)
    }

    func testFullScreenCaptureResetsAfterFailure() async {
        let failed = expectation(description: "capture failed")
        let engine = CaptureEngine(fullScreenCapture: { _ in
            throw ScreenCapture.CaptureError.captureFailed
        })
        engine.onError = { _ in failed.fulfill() }

        engine.captureFullScreen(NSScreen.main!)
        await fulfillment(of: [failed])

        XCTAssertFalse(engine.isActive)
    }

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
        return context.makeImage()!
    }
}
