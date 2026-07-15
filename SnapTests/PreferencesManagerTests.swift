import XCTest
@testable import Snap

@MainActor
final class PreferencesManagerTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!
    private var prefs: PreferencesManager!

    override func setUp() {
        super.setUp()
        suiteName = "SnapTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        prefs = PreferencesManager(defaults: defaults)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    func testRegisteredDefaults() {
        XCTAssertEqual(prefs.imageFormat, "png")
        XCTAssertEqual(prefs.jpegQuality, 0.85, accuracy: 0.0001)
        XCTAssertEqual(prefs.lastLineWidth, 2.0, accuracy: 0.0001)
        XCTAssertEqual(prefs.lastFontSize, 16.0, accuracy: 0.0001)
        XCTAssertTrue(prefs.copyToClipboardAfterCapture)
        XCTAssertFalse(prefs.autoSaveAfterCapture)
    }

    func testValuesRoundTrip() {
        prefs.imageFormat = "jpeg"
        prefs.jpegQuality = 0.6
        prefs.lastLineWidth = 4
        prefs.lastFontSize = 24
        prefs.lastTool = "arrow"
        prefs.lastAnnotationColorHex = "#00FF00FF"

        // A fresh instance over the same suite must read back the stored values.
        let reloaded = PreferencesManager(defaults: defaults)
        XCTAssertEqual(reloaded.imageFormat, "jpeg")
        XCTAssertEqual(reloaded.jpegQuality, 0.6, accuracy: 0.0001)
        XCTAssertEqual(reloaded.lastLineWidth, 4, accuracy: 0.0001)
        XCTAssertEqual(reloaded.lastFontSize, 24, accuracy: 0.0001)
        XCTAssertEqual(reloaded.lastTool, "arrow")
        XCTAssertEqual(reloaded.lastAnnotationColorHex, "#00FF00FF")
    }

    func testSaveDirectoryRoundTrips() {
        let url = URL(fileURLWithPath: "/tmp/snap-test-dir")
        prefs.saveDirectory = url
        XCTAssertEqual(prefs.saveDirectory.path, url.path)
    }
}
