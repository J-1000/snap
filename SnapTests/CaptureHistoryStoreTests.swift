import XCTest
@testable import Snap

@MainActor
final class CaptureHistoryStoreTests: XCTestCase {
    private var directory: URL!

    override func setUp() {
        super.setUp()
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SnapHistoryTests-\(UUID().uuidString)", isDirectory: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: directory)
        super.tearDown()
    }

    func testDisabledHistoryDoesNotWriteCapture() {
        let store = CaptureHistoryStore(directory: directory, isEnabled: { false })

        XCTAssertNil(store.record(makeImage(width: 12, height: 8), scaleFactor: 2))
        XCTAssertTrue(store.entries.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.path))
    }

    func testOpeningDisabledStoreRemovesPreviouslyRetainedHistory() {
        let enabled = CaptureHistoryStore(directory: directory, isEnabled: { true })
        enabled.record(makeImage(width: 12, height: 8), scaleFactor: 1)
        XCTAssertTrue(FileManager.default.fileExists(atPath: directory.path))

        let disabled = CaptureHistoryStore(directory: directory, isEnabled: { false })

        XCTAssertTrue(disabled.entries.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.path))
    }

    func testHistoryPersistsImagesAndEnforcesLimit() {
        let store = CaptureHistoryStore(
            directory: directory,
            maximumEntryCount: 2,
            isEnabled: { true }
        )
        store.record(makeImage(width: 10, height: 8), scaleFactor: 2)
        store.record(makeImage(width: 20, height: 12), scaleFactor: 1)
        store.record(makeImage(width: 30, height: 16), scaleFactor: 1)

        XCTAssertEqual(store.entries.map(\.pixelWidth), [30, 20])
        XCTAssertNotNil(store.image(for: store.entries[0]))

        let reloaded = CaptureHistoryStore(
            directory: directory,
            maximumEntryCount: 2,
            isEnabled: { true }
        )
        XCTAssertEqual(reloaded.entries.map(\.pixelWidth), [30, 20])
    }

    func testRemoveAndClearDeleteStoredEntries() {
        let store = CaptureHistoryStore(directory: directory, isEnabled: { true })
        let first = store.record(makeImage(width: 10, height: 10), scaleFactor: 1)!
        store.record(makeImage(width: 20, height: 20), scaleFactor: 1)

        store.remove(first)
        XCTAssertEqual(store.entries.count, 1)
        XCTAssertNil(store.image(for: first))

        store.clear()
        XCTAssertTrue(store.entries.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.path))
    }

    private func makeImage(width: Int, height: Int) -> CGImage {
        let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        context.setFillColor(NSColor.systemBlue.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()!
    }
}
