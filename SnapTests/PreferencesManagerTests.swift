import XCTest
import Carbon.HIToolbox
@testable import Snap

final class PreferencesManagerTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "SnapTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    @MainActor func testRegisteredDefaults() {
        let prefs = PreferencesManager(defaults: defaults)
        XCTAssertEqual(prefs.imageFormat, "png")
        XCTAssertEqual(prefs.jpegQuality, 0.85, accuracy: 0.0001)
        XCTAssertEqual(prefs.lastLineWidth, 2.0, accuracy: 0.0001)
        XCTAssertEqual(prefs.lastFontSize, 16.0, accuracy: 0.0001)
        XCTAssertTrue(prefs.copyToClipboardAfterCapture)
        XCTAssertFalse(prefs.autoSaveAfterCapture)
        XCTAssertFalse(prefs.captureHDR)
        XCTAssertTrue(prefs.windowCaptureIncludesShadow)
        XCTAssertEqual(prefs.windowCaptureBackground, WindowCaptureBackground.transparent.rawValue)
        XCTAssertEqual(prefs.areaCaptureShortcut, .areaCapture)
        XCTAssertEqual(prefs.fullScreenCaptureShortcut, .fullScreenCapture)
        XCTAssertFalse(prefs.captureHistoryEnabled)
    }

    @MainActor func testValuesRoundTrip() {
        let prefs = PreferencesManager(defaults: defaults)
        prefs.imageFormat = "jpeg"
        prefs.jpegQuality = 0.6
        prefs.lastLineWidth = 4
        prefs.lastFontSize = 24
        prefs.lastTool = "arrow"
        prefs.lastAnnotationColorHex = "#00FF00FF"
        prefs.windowCaptureIncludesShadow = false
        prefs.windowCaptureBackground = WindowCaptureBackground.black.rawValue
        let area = SavedCaptureArea(
            rect: NSRect(x: -20, y: 40, width: 640, height: 480),
            displayID: 42
        )
        prefs.lastAreaCapture = area
        prefs.captureHDR = true
        let areaShortcut = HotKeyManager.HotKey(
            keyCode: CGKeyCode(kVK_ANSI_A),
            modifiers: [.maskCommand, .maskControl]
        )
        let fullScreenShortcut = HotKeyManager.HotKey(
            keyCode: CGKeyCode(kVK_ANSI_F),
            modifiers: [.maskAlternate, .maskControl]
        )
        prefs.areaCaptureShortcut = areaShortcut
        prefs.fullScreenCaptureShortcut = fullScreenShortcut
        prefs.captureHistoryEnabled = true

        // A fresh instance over the same suite must read back the stored values.
        let reloaded = PreferencesManager(defaults: defaults)
        XCTAssertEqual(reloaded.imageFormat, "jpeg")
        XCTAssertEqual(reloaded.jpegQuality, 0.6, accuracy: 0.0001)
        XCTAssertEqual(reloaded.lastLineWidth, 4, accuracy: 0.0001)
        XCTAssertEqual(reloaded.lastFontSize, 24, accuracy: 0.0001)
        XCTAssertEqual(reloaded.lastTool, "arrow")
        XCTAssertEqual(reloaded.lastAnnotationColorHex, "#00FF00FF")
        XCTAssertFalse(reloaded.windowCaptureIncludesShadow)
        XCTAssertEqual(reloaded.windowCaptureBackground, WindowCaptureBackground.black.rawValue)
        XCTAssertEqual(reloaded.lastAreaCapture, area)
        XCTAssertTrue(reloaded.captureHDR)
        XCTAssertEqual(reloaded.areaCaptureShortcut, areaShortcut)
        XCTAssertEqual(reloaded.fullScreenCaptureShortcut, fullScreenShortcut)
        XCTAssertTrue(reloaded.captureHistoryEnabled)
    }

    @MainActor func testSaveDirectoryRoundTrips() {
        let prefs = PreferencesManager(defaults: defaults)
        let url = URL(fileURLWithPath: "/tmp/snap-test-dir")
        prefs.saveDirectory = url
        XCTAssertEqual(prefs.saveDirectory.path, url.path)
    }
}
