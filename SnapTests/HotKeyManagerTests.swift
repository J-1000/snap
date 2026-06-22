import XCTest
import CoreGraphics
@testable import Snap

final class HotKeyManagerTests: XCTestCase {
    private let cmdShiftAlt: CGEventFlags = [.maskCommand, .maskShift, .maskAlternate]
    private var areaKey: CGKeyCode { HotKeyManager.HotKey.areaCapture.keyCode }
    private var fullScreenKey: CGKeyCode { HotKeyManager.HotKey.fullScreenCapture.keyCode }

    func testAreaCaptureExactMatch() {
        XCTAssertEqual(HotKeyManager.matchedAction(keyCode: areaKey, flags: cmdShiftAlt), .area)
    }

    func testFullScreenCaptureExactMatch() {
        XCTAssertEqual(HotKeyManager.matchedAction(keyCode: fullScreenKey, flags: cmdShiftAlt), .fullScreen)
    }

    func testSupersetModifiersAreRejected() {
        let withControl: CGEventFlags = [.maskCommand, .maskShift, .maskAlternate, .maskControl]
        XCTAssertNil(HotKeyManager.matchedAction(keyCode: areaKey, flags: withControl))
    }

    func testMissingModifierIsRejected() {
        let withoutAlt: CGEventFlags = [.maskCommand, .maskShift]
        XCTAssertNil(HotKeyManager.matchedAction(keyCode: areaKey, flags: withoutAlt))
    }

    func testWrongKeyIsPassedThrough() {
        XCTAssertNil(HotKeyManager.matchedAction(keyCode: 0, flags: cmdShiftAlt))
    }

    func testIrrelevantFlagsAreIgnored() {
        // Caps lock and other non-modifier flags must not affect matching.
        let withCaps: CGEventFlags = [.maskCommand, .maskShift, .maskAlternate, .maskAlphaShift]
        XCTAssertEqual(HotKeyManager.matchedAction(keyCode: areaKey, flags: withCaps), .area)
    }
}
