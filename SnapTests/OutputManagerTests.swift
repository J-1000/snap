import XCTest
@testable import Snap

final class OutputManagerTests: XCTestCase {

    private var tempDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    // MARK: - saveImage

    func testSaveImageCachesLastImage() {
        let image = createTestImage(width: 50, height: 50)
        OutputManager.saveImage(image)
        XCTAssertNotNil(OutputManager.lastCapturedImage)
        XCTAssertEqual(OutputManager.lastCapturedImage?.width, 50)
        XCTAssertEqual(OutputManager.lastCapturedImage?.height, 50)
    }

    func testSaveImageOverwritesPrevious() {
        let image1 = createTestImage(width: 50, height: 50)
        let image2 = createTestImage(width: 100, height: 100)

        OutputManager.saveImage(image1)
        OutputManager.saveImage(image2)

        XCTAssertEqual(OutputManager.lastCapturedImage?.width, 100)
    }

    // MARK: - saveToFile

    func testSaveToFileCreatesPNG() {
        let image = createTestImage(width: 100, height: 100)
        let url = tempDir.appendingPathComponent("test.png")

        let success = OutputManager.saveToFile(image, url: url)

        XCTAssertTrue(success)
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
    }

    func testSaveToFileWritesNonEmptyFile() {
        let image = createTestImage(width: 100, height: 100)
        let url = tempDir.appendingPathComponent("test.png")

        OutputManager.saveToFile(image, url: url)

        let data = try? Data(contentsOf: url)
        XCTAssertNotNil(data)
        XCTAssertGreaterThan(data?.count ?? 0, 0)
    }

    func testSaveToFileProducesValidPNG() {
        let image = createTestImage(width: 64, height: 64)
        let url = tempDir.appendingPathComponent("test.png")

        OutputManager.saveToFile(image, url: url)

        // Verify it's a valid image by loading it back
        guard let data = try? Data(contentsOf: url),
              let source = CGImageSourceCreateWithData(data as CFData, nil),
              let loadedImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            XCTFail("Could not load saved PNG")
            return
        }
        XCTAssertEqual(loadedImage.width, 64)
        XCTAssertEqual(loadedImage.height, 64)
    }

    func testSaveToFileInvalidPathReturnsFalse() {
        let image = createTestImage(width: 10, height: 10)
        let url = URL(fileURLWithPath: "/nonexistent/path/test.png")

        let success = OutputManager.saveToFile(image, url: url)
        XCTAssertFalse(success)
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
