import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController?
    private let hotKeyManager = HotKeyManager()
    let captureEngine = CaptureEngine()
    private var annotationWindow: AnnotationWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusBarController = StatusBarController()

        captureEngine.onImageCaptured = { [weak self] image in
            self?.showAnnotationWindow(image: image)
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

    private func showAnnotationWindow(image: CGImage) {
        // Position at center of main screen
        let screen = NSScreen.main ?? NSScreen.screens[0]
        let imageSize = NSSize(width: CGFloat(image.width), height: CGFloat(image.height))
        let x = screen.frame.midX - imageSize.width / 2
        let y = screen.frame.midY - imageSize.height / 2
        let screenRect = NSRect(origin: NSPoint(x: x, y: y), size: imageSize)

        let window = AnnotationWindow(image: image, screenRect: screenRect)

        window.onCopy = { [weak self] in
            OutputManager.copyToClipboard(image)
            OutputManager.showNotification(title: "Snap", text: "Copied to clipboard")
            self?.dismissAnnotationWindow()
        }
        window.onSave = { [weak self] in
            let prefs = PreferencesManager.shared
            let url = prefs.saveDirectory.appendingPathComponent(
                FileNaming.defaultFilename(extension: prefs.imageFormat))
            if OutputManager.saveToFile(image, url: url) {
                OutputManager.showNotification(title: "Snap", text: "Saved to \(url.lastPathComponent)")
            }
            self?.dismissAnnotationWindow()
        }
        window.onSaveAs = {
            OutputManager.saveWithDialog(image)
        }
        window.onClose = { [weak self] in
            self?.dismissAnnotationWindow()
        }

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        annotationWindow = window
    }

    private func dismissAnnotationWindow() {
        annotationWindow?.orderOut(nil)
        annotationWindow = nil
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
