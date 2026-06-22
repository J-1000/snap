import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController?
    private let hotKeyManager = HotKeyManager()
    let captureEngine = CaptureEngine()
    private var annotationWindow: AnnotationWindow?
    private var captureHUD: CaptureHUD?
    private var lastCaptureScaleFactor: CGFloat = 1.0

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusBarController = StatusBarController()

        captureEngine.onImageCaptured = { [weak self] image, scaleFactor, selectionRect in
            self?.handleCapturedImage(image, scaleFactor: scaleFactor, selectionRect: selectionRect)
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

    func handleCapturedImage(_ image: CGImage, scaleFactor: CGFloat = 1.0, showUI: Bool = true, selectionRect: NSRect? = nil) {
        lastCaptureScaleFactor = scaleFactor
        OutputManager.saveImage(image, scaleFactor: scaleFactor)
        let prefs = PreferencesManager.shared
        var performedAutomaticOutput = false

        if prefs.copyToClipboardAfterCapture {
            performedAutomaticOutput = OutputManager.copyToClipboard(image, scaleFactor: scaleFactor) || performedAutomaticOutput
        }

        if prefs.autoSaveAfterCapture {
            if let url = OutputManager.saveToDefaultLocation(image, scaleFactor: scaleFactor) {
                performedAutomaticOutput = true
                OutputManager.showNotification(title: "Snap", text: "Saved to \(url.lastPathComponent)")
            }
        }
        if showUI {
            if prefs.openEditorAfterCapture {
                showAnnotationWindow(image: image, scaleFactor: scaleFactor, selectionRect: selectionRect)
            } else {
                // Otherwise show the post-capture HUD so the shot and the editor
                // are always reachable, even after an automatic copy/save.
                showCaptureHUD(image: image, scaleFactor: scaleFactor, selectionRect: selectionRect)
            }
        }
    }

    private func showCaptureHUD(image: CGImage, scaleFactor: CGFloat, selectionRect: NSRect?) {
        let hud = CaptureHUD(image: image)
        hud.onAnnotate = { [weak self] in
            self?.showAnnotationWindow(image: image, scaleFactor: scaleFactor, selectionRect: selectionRect)
        }
        hud.onCopy = {
            if OutputManager.copyToClipboard(image, scaleFactor: scaleFactor) {
                OutputManager.showNotification(title: "Snap", text: "Copied to clipboard")
            }
        }
        hud.onSave = {
            if let url = OutputManager.saveToDefaultLocation(image, scaleFactor: scaleFactor) {
                OutputManager.showNotification(title: "Snap", text: "Saved to \(url.lastPathComponent)")
            }
        }
        hud.onDismiss = { [weak self] in self?.captureHUD = nil }
        captureHUD = hud
        hud.present()
    }

    /// Keep a window of `size` fully on screen within `area`, pinning to the
    /// min edge when the window is larger than the available space.
    static func clampOrigin(_ origin: NSPoint, size: NSSize, into area: NSRect) -> NSPoint {
        var x = origin.x
        var y = origin.y
        x = size.width <= area.width ? min(max(x, area.minX), area.maxX - size.width) : area.minX
        y = size.height <= area.height ? min(max(y, area.minY), area.maxY - size.height) : area.minY
        return NSPoint(x: x, y: y)
    }

    private func showAnnotationWindow(image: CGImage, scaleFactor: CGFloat, selectionRect: NSRect? = nil) {
        let size = AnnotationWindow.contentSize(for: image, scaleFactor: scaleFactor)
        let screen = selectionRect.flatMap { rect in
            NSScreen.screens.first { $0.frame.intersects(rect) }
        } ?? NSScreen.main ?? NSScreen.screens[0]

        let proposed: NSPoint
        if let sel = selectionRect {
            // Align the image canvas (which sits above the action toolbar) with
            // the on-screen selection so the editor opens where you captured.
            proposed = NSPoint(x: sel.minX, y: sel.minY - ActionToolbar.height)
        } else {
            proposed = NSPoint(x: screen.frame.midX - size.width / 2,
                               y: screen.frame.midY - size.height / 2)
        }
        let origin = Self.clampOrigin(proposed, size: size, into: screen.visibleFrame)

        let window = AnnotationWindow(image: image, scaleFactor: scaleFactor, origin: origin)

        window.onCopy = { [weak self, weak window] in
            guard let window = window else { return }
            let output = window.annotationView.annotationManager.composite(onto: image) ?? image
            OutputManager.saveImage(output, scaleFactor: self?.lastCaptureScaleFactor ?? 1.0)
            _ = OutputManager.copyToClipboard(output, scaleFactor: self?.lastCaptureScaleFactor)
            OutputManager.showNotification(title: "Snap", text: "Copied to clipboard")
            self?.dismissAnnotationWindow()
        }
        window.onSave = { [weak self, weak window] in
            guard let window = window else { return }
            let output = window.annotationView.annotationManager.composite(onto: image) ?? image
            OutputManager.saveImage(output, scaleFactor: self?.lastCaptureScaleFactor ?? 1.0)
            if let url = OutputManager.saveToDefaultLocation(output, scaleFactor: self?.lastCaptureScaleFactor) {
                OutputManager.showNotification(title: "Snap", text: "Saved to \(url.lastPathComponent)")
            }
            self?.dismissAnnotationWindow()
        }
        window.onSaveAs = { [weak self, weak window] in
            guard let window = window else { return }
            let output = window.annotationView.annotationManager.composite(onto: image) ?? image
            OutputManager.saveImage(output, scaleFactor: self?.lastCaptureScaleFactor ?? 1.0)
            OutputManager.saveWithDialog(output)
        }
        window.onReverseSearch = { [weak self, weak window] in
            guard let window = window else { return }
            let output = window.annotationView.annotationManager.composite(onto: image) ?? image
            OutputManager.saveImage(output, scaleFactor: self?.lastCaptureScaleFactor ?? 1.0)
            _ = OutputManager.reverseImageSearch(output, scaleFactor: self?.lastCaptureScaleFactor)
            self?.dismissAnnotationWindow()
        }
        window.onPrint = { [weak self, weak window] in
            guard let window = window else { return }
            let output = window.annotationView.annotationManager.composite(onto: image) ?? image
            OutputManager.saveImage(output, scaleFactor: self?.lastCaptureScaleFactor ?? 1.0)
            _ = OutputManager.printImage(output)
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
        if let url = OutputManager.saveToDefaultLocation(image, scaleFactor: OutputManager.lastCapturedScaleFactor) {
            OutputManager.showNotification(title: "Snap", text: "Saved to \(url.lastPathComponent)")
        }
    }

    @objc func saveScreenshotAs() {
        guard let image = OutputManager.lastCapturedImage else { return }
        OutputManager.saveWithDialog(image)
    }
}
