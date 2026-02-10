import AppKit

final class StatusBarController {
    private var statusItem: NSStatusItem
    private var preferencesWindow: PreferencesWindow?

    init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "camera.viewfinder", accessibilityDescription: "Snap")
        }

        statusItem.menu = buildMenu()
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()

        menu.addItem(NSMenuItem(title: "Capture Area", action: #selector(captureArea), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Capture Full Screen", action: #selector(captureFullScreen), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())

        let saveItem = NSMenuItem(title: "Save Last Screenshot", action: #selector(saveScreenshot), keyEquivalent: "s")
        saveItem.keyEquivalentModifierMask = [.command]
        menu.addItem(saveItem)

        let saveAsItem = NSMenuItem(title: "Save Last Screenshot As…", action: #selector(saveScreenshotAs), keyEquivalent: "s")
        saveAsItem.keyEquivalentModifierMask = [.command, .shift]
        menu.addItem(saveAsItem)

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

    @objc private func captureFullScreen() {
        guard let delegate = NSApp.delegate as? AppDelegate else { return }
        delegate.startFullScreenCapture()
    }

    @objc private func saveScreenshot() {
        guard let delegate = NSApp.delegate as? AppDelegate else { return }
        delegate.saveScreenshot()
    }

    @objc private func saveScreenshotAs() {
        guard let delegate = NSApp.delegate as? AppDelegate else { return }
        delegate.saveScreenshotAs()
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
