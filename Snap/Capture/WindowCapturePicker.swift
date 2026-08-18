import AppKit
import ScreenCaptureKit

enum WindowCaptureBackground: String, CaseIterable {
    case transparent
    case white
    case black

    var title: String {
        switch self {
        case .transparent: "Transparent"
        case .white: "White"
        case .black: "Black"
        }
    }

    var color: CGColor {
        switch self {
        case .transparent: NSColor.clear.cgColor
        case .white: NSColor.white.cgColor
        case .black: NSColor.black.cgColor
        }
    }
}

struct WindowCaptureOptions: Equatable {
    var includesShadow: Bool
    var background: WindowCaptureBackground
}

struct WindowCaptureSelection {
    let window: SCWindow
    let options: WindowCaptureOptions
}

@MainActor
enum WindowCapturePicker {
    static func chooseWindow(from windows: [SCWindow]) -> WindowCaptureSelection? {
        let candidates = windows
            .filter(isUsefulWindow)
            .sorted { displayName(for: $0).localizedCaseInsensitiveCompare(displayName(for: $1)) == .orderedAscending }

        guard !candidates.isEmpty else {
            OutputManager.showFailure("No capturable windows are currently visible")
            return nil
        }

        let alert = NSAlert()
        alert.messageText = "Capture Window"
        alert.informativeText = "Choose a visible window and how its surrounding pixels should be rendered."
        alert.addButton(withTitle: "Capture")
        alert.addButton(withTitle: "Cancel")

        let accessory = NSView(frame: NSRect(x: 0, y: 0, width: 360, height: 92))
        let windowPopup = NSPopUpButton(frame: NSRect(x: 0, y: 62, width: 360, height: 26))
        for window in candidates {
            windowPopup.addItem(withTitle: displayName(for: window))
        }
        windowPopup.setAccessibilityLabel("Window to capture")

        let shadowButton = NSButton(checkboxWithTitle: "Include window shadow", target: nil, action: nil)
        shadowButton.frame = NSRect(x: 2, y: 32, width: 190, height: 24)
        shadowButton.state = PreferencesManager.shared.windowCaptureIncludesShadow ? .on : .off

        let backgroundLabel = NSTextField(labelWithString: "Background:")
        backgroundLabel.frame = NSRect(x: 2, y: 2, width: 90, height: 22)
        let backgroundPopup = NSPopUpButton(frame: NSRect(x: 92, y: 0, width: 150, height: 26))
        backgroundPopup.addItems(withTitles: WindowCaptureBackground.allCases.map(\.title))
        let savedBackground = WindowCaptureBackground(rawValue: PreferencesManager.shared.windowCaptureBackground)
            ?? .transparent
        backgroundPopup.selectItem(withTitle: savedBackground.title)
        backgroundPopup.setAccessibilityLabel("Window capture background")

        accessory.addSubview(windowPopup)
        accessory.addSubview(shadowButton)
        accessory.addSubview(backgroundLabel)
        accessory.addSubview(backgroundPopup)
        alert.accessoryView = accessory

        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn else { return nil }

        let index = max(windowPopup.indexOfSelectedItem, 0)
        let background = WindowCaptureBackground.allCases.first {
            $0.title == backgroundPopup.titleOfSelectedItem
        } ?? .transparent
        let options = WindowCaptureOptions(
            includesShadow: shadowButton.state == .on,
            background: background
        )
        PreferencesManager.shared.windowCaptureIncludesShadow = options.includesShadow
        PreferencesManager.shared.windowCaptureBackground = options.background.rawValue
        return WindowCaptureSelection(window: candidates[index], options: options)
    }

    static func displayName(for window: SCWindow) -> String {
        let application = window.owningApplication?.applicationName ?? "Unknown App"
        let title = window.title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return title.isEmpty ? application : "\(application) — \(title)"
    }

    private static func isUsefulWindow(_ window: SCWindow) -> Bool {
        guard window.isOnScreen,
              window.windowLayer == 0,
              window.frame.width >= 64,
              window.frame.height >= 64 else {
            return false
        }
        return window.owningApplication?.bundleIdentifier != Bundle.main.bundleIdentifier
    }
}
