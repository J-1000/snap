import AppKit

@MainActor
final class StatusBarController {
    private var statusItem: NSStatusItem
    private var preferencesWindow: PreferencesWindow?
    private var captureHistoryWindow: CaptureHistoryWindowController?
    private var successFlashWorkItem: DispatchWorkItem?

    init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "camera.viewfinder", accessibilityDescription: "Snap")
        }

        statusItem.menu = buildMenu()
    }

    /// Briefly flash a checkmark on the menu-bar icon as a lightweight
    /// acknowledgement when notifications are disabled.
    func flashSuccess() {
        guard let button = statusItem.button else { return }
        successFlashWorkItem?.cancel()
        button.image = NSImage(systemSymbolName: "checkmark.circle.fill", accessibilityDescription: "Done")
        let item = DispatchWorkItem { [weak self, weak button] in
            button?.image = NSImage(
                systemSymbolName: "camera.viewfinder",
                accessibilityDescription: "Snap"
            )
            self?.successFlashWorkItem = nil
        }
        successFlashWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7, execute: item)
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()

        menu.addItem(NSMenuItem(title: "Capture Area", action: #selector(captureArea), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Capture Window…", action: #selector(captureWindow), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Repeat Last Area", action: #selector(repeatLastArea), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Capture Scrolling Area…", action: #selector(captureScrollingArea), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Capture Full Screen", action: #selector(captureFullScreen), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Capture Full Screen (5s delay)", action: #selector(captureFullScreenDelayed), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Capture Text (OCR)", action: #selector(captureText), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Capture QR Code", action: #selector(captureQRCode), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())

        let saveItem = NSMenuItem(title: "Save Last Screenshot", action: #selector(saveScreenshot), keyEquivalent: "s")
        saveItem.keyEquivalentModifierMask = [.command]
        menu.addItem(saveItem)

        let saveAsItem = NSMenuItem(title: "Save Last Screenshot As…", action: #selector(saveScreenshotAs), keyEquivalent: "s")
        saveAsItem.keyEquivalentModifierMask = [.command, .shift]
        menu.addItem(saveAsItem)

        menu.addItem(NSMenuItem(title: "Pin Last Screenshot", action: #selector(pinLastScreenshot), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Capture History…", action: #selector(openCaptureHistory), keyEquivalent: ""))

        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Preferences…", action: #selector(openPreferences), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "About Snap", action: #selector(openAbout), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Quit Snap", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        for item in menu.items where item.action != #selector(NSApplication.terminate(_:)) {
            item.target = self
        }

        return menu
    }

    @objc private func captureArea() {
        guard let delegate = NSApp.delegate as? AppDelegate else { return }
        delegate.startAreaCapture()
    }

    @objc private func captureWindow() {
        guard let delegate = NSApp.delegate as? AppDelegate else { return }
        delegate.startWindowCapture()
    }

    @objc private func repeatLastArea() {
        guard let delegate = NSApp.delegate as? AppDelegate else { return }
        delegate.repeatLastAreaCapture()
    }

    @objc private func captureScrollingArea() {
        guard let delegate = NSApp.delegate as? AppDelegate else { return }
        delegate.startScrollingCapture()
    }

    @objc private func captureFullScreen() {
        guard let delegate = NSApp.delegate as? AppDelegate else { return }
        delegate.startFullScreenCapture()
    }

    @objc private func captureFullScreenDelayed() {
        guard let delegate = NSApp.delegate as? AppDelegate else { return }
        delegate.startDelayedFullScreenCapture()
    }

    @objc private func captureText() {
        guard let delegate = NSApp.delegate as? AppDelegate else { return }
        delegate.startTextCapture()
    }

    @objc private func captureQRCode() {
        guard let delegate = NSApp.delegate as? AppDelegate else { return }
        delegate.startQRCodeCapture()
    }

    @objc private func saveScreenshot() {
        guard let delegate = NSApp.delegate as? AppDelegate else { return }
        delegate.saveScreenshot()
    }

    @objc private func saveScreenshotAs() {
        guard let delegate = NSApp.delegate as? AppDelegate else { return }
        delegate.saveScreenshotAs()
    }

    @objc private func pinLastScreenshot() {
        guard let delegate = NSApp.delegate as? AppDelegate else { return }
        delegate.pinLastScreenshot()
    }

    @objc private func openCaptureHistory() {
        if captureHistoryWindow == nil {
            captureHistoryWindow = CaptureHistoryWindowController()
        }
        captureHistoryWindow?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func openPreferences() {
        if preferencesWindow == nil {
            preferencesWindow = PreferencesWindow()
        }
        preferencesWindow?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func openAbout() {
        NSApp.orderFrontStandardAboutPanel(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
