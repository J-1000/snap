import XCTest

@MainActor
final class SnapUITests: XCTestCase {
    private var app: XCUIApplication!

    func testPreferencesExposeShortcutOutputAndPrivacyControls() {
        launch("--ui-testing-preferences")

        XCTAssertTrue(app.windows["Snap Preferences"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["area-capture-shortcut"].exists)
        XCTAssertTrue(app.buttons["full-screen-capture-shortcut"].exists)
        XCTAssertTrue(app.checkBoxes["Copy to clipboard after capture"].exists)
        XCTAssertTrue(app.checkBoxes["Keep up to 20 recent captures in local history"].exists)
        XCTAssertTrue(app.buttons["Clear Capture History…"].exists)
    }

    func testEditorExposesEditingAndCanvasActions() {
        launch("--ui-testing-editor")

        XCTAssertTrue(app.buttons["Undo"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Redo"].exists)
        XCTAssertTrue(app.buttons["Red annotation color"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["Crop"].exists)
        XCTAssertTrue(app.buttons["Zoom Out"].exists)
        XCTAssertTrue(app.buttons["Zoom to Fit"].exists)
        XCTAssertTrue(app.buttons["Zoom In"].exists)
        XCTAssertTrue(app.buttons["Copy"].exists)
    }

    func testCaptureHUDExposesEveryAction() {
        launch("--ui-testing-hud")

        XCTAssertTrue(app.groups["Screenshot actions"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Annotate"].exists)
        XCTAssertTrue(app.buttons["Copy"].exists)
        XCTAssertTrue(app.buttons["Save"].exists)
        XCTAssertTrue(app.buttons["Pin Screenshot"].exists)
        XCTAssertTrue(app.buttons["Dismiss"].exists)
    }

    func testCaptureOverlayHasVoiceOverInstructions() {
        launch("--ui-testing-overlay")

        XCTAssertTrue(
            app.groups["Screen capture area selector"].firstMatch.waitForExistence(timeout: 5)
        )
    }

    private func launch(_ mode: String) {
        app = XCUIApplication()
        app.launchArguments = [mode]
        app.launch()
    }
}
