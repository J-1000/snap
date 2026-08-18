import XCTest
import CoreGraphics
import Carbon.HIToolbox
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

    func testCustomShortcutsAreMatched() {
        let area = HotKeyManager.HotKey(
            keyCode: CGKeyCode(kVK_ANSI_A),
            modifiers: [.maskCommand, .maskControl]
        )
        let full = HotKeyManager.HotKey(
            keyCode: CGKeyCode(kVK_ANSI_F),
            modifiers: [.maskAlternate, .maskControl]
        )

        XCTAssertEqual(
            HotKeyManager.matchedAction(
                keyCode: area.keyCode,
                flags: area.modifiers,
                areaShortcut: area,
                fullScreenShortcut: full
            ),
            .area
        )
        XCTAssertEqual(
            HotKeyManager.matchedAction(
                keyCode: full.keyCode,
                flags: full.modifiers,
                areaShortcut: area,
                fullScreenShortcut: full
            ),
            .fullScreen
        )
    }

    func testDuplicateAndSystemScreenshotShortcutsAreRejected() {
        let duplicate = HotKeyManager.HotKey.areaCapture
        XCTAssertNotNil(
            HotKeyManager.validationError(for: duplicate, conflictingWith: duplicate)
        )

        let systemScreenshot = HotKeyManager.HotKey(
            keyCode: CGKeyCode(kVK_ANSI_4),
            modifiers: [.maskCommand, .maskShift]
        )
        XCTAssertNotNil(
            HotKeyManager.validationError(for: systemScreenshot, conflictingWith: nil)
        )

        let typingShortcut = HotKeyManager.HotKey(
            keyCode: CGKeyCode(kVK_ANSI_A),
            modifiers: [.maskShift]
        )
        XCTAssertNotNil(
            HotKeyManager.validationError(for: typingShortcut, conflictingWith: nil)
        )
    }

    func testShortcutDisplayUsesStandardModifierGlyphs() {
        XCTAssertEqual(HotKeyManager.HotKey.areaCapture.displayString, "⌥⇧⌘4")
    }
}
