import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController?
    private let hotKeyManager = HotKeyManager()
    let captureEngine = CaptureEngine()

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusBarController = StatusBarController()

        captureEngine.onImageCaptured = { image in
            let prefs = PreferencesManager.shared
            OutputManager.saveImage(image)

            var messages: [String] = []

            if prefs.copyToClipboardAfterCapture {
                if OutputManager.copyToClipboard(image) {
                    messages.append("Copied to clipboard")
                }
            }

            if prefs.autoSaveAfterCapture {
                let url = prefs.saveDirectory.appendingPathComponent(
                    FileNaming.defaultFilename(extension: prefs.imageFormat))
                if OutputManager.saveToFile(image, url: url) {
                    messages.append("Saved to \(url.lastPathComponent)")
                }
            }

            if !messages.isEmpty {
                OutputManager.showNotification(title: "Snap", text: messages.joined(separator: " · "))
            }
        }

        captureEngine.onError = { error in
            NSLog("Snap capture error: \(error.localizedDescription)")
            OutputManager.showNotification(title: "Snap", text: "Capture failed: \(error.localizedDescription)")
        }

        hotKeyManager.onAreaCapture = { [weak self] in
            self?.startAreaCapture()
        }
        hotKeyManager.onFullScreenCapture = { [weak self] in
            self?.startFullScreenCapture()
        }
        hotKeyManager.start()
    }

    func startAreaCapture() {
        guard !captureEngine.isActive else { return }
        captureEngine.startAreaSelection()
    }

    func startFullScreenCapture() {
        guard let screen = NSScreen.main else { return }
        captureEngine.captureFullScreen(screen)
    }

    @objc func saveScreenshot() {
        guard let image = OutputManager.lastCapturedImage else { return }
        if OutputManager.saveToFile(image) {
            OutputManager.showNotification(title: "Snap", text: "Saved to Desktop")
        }
    }

    @objc func saveScreenshotAs() {
        guard let image = OutputManager.lastCapturedImage else { return }
        OutputManager.saveWithDialog(image)
    }
}
