import AppKit

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController?
    private let hotKeyManager = HotKeyManager()
    let captureEngine = CaptureEngine()
    private var annotationWindow: AnnotationWindow?
    private var captureHUD: CaptureHUD?
    private var lastCaptureScaleFactor: CGFloat = 1.0
    private var isShowingPermissionAlert = false
    private var pendingTextCapture = false
    private var delayedCaptureWorkItem: DispatchWorkItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // App-hosted unit tests launch Snap before loading the test bundle.
        // Keep that host inert: tests must not install a global event tap,
        // prompt for Screen Recording permission, or create menu-bar UI.
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else {
            return
        }

        statusBarController = StatusBarController()

        captureEngine.onImageCaptured = { [weak self] image, scaleFactor, selectionRect in
            self?.handleCapturedImage(image, scaleFactor: scaleFactor, selectionRect: selectionRect)
        }

        captureEngine.onError = { [weak self] error in
            NSLog("Snap capture error: \(error.localizedDescription)")
            self?.pendingTextCapture = false
            if !ScreenCapture.hasScreenRecordingPermission() {
                self?.presentScreenRecordingPermissionAlert()
            } else {
                OutputManager.showFailure("Capture failed: \(error.localizedDescription)")
            }
        }

        captureEngine.onCancel = { [weak self] in
            self?.pendingTextCapture = false
        }

        hotKeyManager.onAreaCapture = { [weak self] in
            self?.startAreaCapture()
        }
        hotKeyManager.onFullScreenCapture = { [weak self] in
            self?.startFullScreenCapture()
        }
        if !hotKeyManager.start() {
            HotKeyManager.requestAccessibilityPermission()
        }

        // Prime Screen Recording permission on first launch so the system adds
        // Snap to the Privacy list before the first capture.
        if !ScreenCapture.hasScreenRecordingPermission() {
            ScreenCapture.requestScreenRecordingPermission()
        }
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil,
              !hotKeyManager.isRunning,
              HotKeyManager.hasAccessibilityPermission else {
            return
        }
        hotKeyManager.start()
    }

    private func presentScreenRecordingPermissionAlert() {
        guard !isShowingPermissionAlert else { return }
        isShowingPermissionAlert = true
        let alert = NSAlert()
        alert.messageText = "Screen Recording Permission Needed"
        alert.informativeText = "Snap needs Screen Recording permission to capture your screen.\n\nEnable it in System Settings ▸ Privacy & Security ▸ Screen Recording, then try again."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Cancel")
        NSApp.activate(ignoringOtherApps: true)
        let response = alert.runModal()
        isShowingPermissionAlert = false
        if response == .alertFirstButtonReturn,
           let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }

    func startAreaCapture() {
        guard !captureEngine.isActive else { return }
        cancelDelayedCapture()
        captureEngine.startAreaSelection()
    }

    func startFullScreenCapture() {
        guard let screen = NSScreen.main else { return }
        cancelDelayedCapture()
        captureEngine.captureFullScreen(screen)
    }

    func startDelayedFullScreenCapture() {
        guard delayedCaptureWorkItem == nil, !captureEngine.isActive else { return }
        OutputManager.showNotification(title: "Snap", text: "Capturing full screen in 5 seconds…")
        let item = DispatchWorkItem { [weak self] in
            self?.delayedCaptureWorkItem = nil
            self?.startFullScreenCapture()
        }
        delayedCaptureWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 5, execute: item)
    }

    func startTextCapture() {
        guard !captureEngine.isActive else { return }
        cancelDelayedCapture()
        pendingTextCapture = true
        captureEngine.startAreaSelection()
    }

    private func cancelDelayedCapture() {
        delayedCaptureWorkItem?.cancel()
        delayedCaptureWorkItem = nil
    }

    private func recognizeText(in image: CGImage) {
        TextRecognizer.recognize(in: image) { [weak self] text in
            guard let text, !text.isEmpty else {
                OutputManager.showFailure("No text found")
                return
            }
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            if pasteboard.setString(text, forType: .string) {
                self?.confirm("Text copied to clipboard")
            } else {
                OutputManager.showFailure("Could not copy recognized text")
            }
        }
    }

    func handleCapturedImage(_ image: CGImage, scaleFactor: CGFloat = 1.0, showUI: Bool = true, selectionRect: NSRect? = nil) {
        if pendingTextCapture {
            pendingTextCapture = false
            recognizeText(in: image)
            return
        }
        lastCaptureScaleFactor = scaleFactor
        OutputManager.cacheLastCapture(image, scaleFactor: scaleFactor)
        let prefs = PreferencesManager.shared
        var automaticConfirmations: [String] = []

        if prefs.copyToClipboardAfterCapture {
            if OutputManager.copyToClipboard(image, scaleFactor: scaleFactor) {
                automaticConfirmations.append("Copied to clipboard")
            } else if showUI {
                OutputManager.showFailure("Copy failed")
            }
        }

        if prefs.autoSaveAfterCapture {
            if let url = OutputManager.saveToDefaultLocation(image, scaleFactor: scaleFactor) {
                automaticConfirmations.append("Saved to \(url.lastPathComponent)")
            } else if showUI {
                OutputManager.showFailure("Auto-save failed")
            }
        }
        if showUI, !automaticConfirmations.isEmpty {
            confirm(automaticConfirmations.joined(separator: " • "))
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
        hud.onCopy = { [weak self] in
            if OutputManager.copyToClipboard(image, scaleFactor: scaleFactor) {
                self?.confirm("Copied to clipboard")
            } else {
                OutputManager.showFailure("Copy failed")
            }
        }
        hud.onSave = { [weak self] in
            if let url = OutputManager.saveToDefaultLocation(image, scaleFactor: scaleFactor) {
                self?.confirm("Saved to \(url.lastPathComponent)")
            } else {
                OutputManager.showFailure("Save failed")
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
        let screen = selectionRect.flatMap { rect in
            NSScreen.screens.first { $0.frame.intersects(rect) }
        } ?? NSScreen.main ?? NSScreen.screens[0]
        let editorScaleFactor = AnnotationWindow.fittedScaleFactor(
            for: image,
            captureScaleFactor: scaleFactor,
            availableSize: screen.visibleFrame.size
        )
        let size = AnnotationWindow.contentSize(for: image, scaleFactor: editorScaleFactor)

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

        let window = AnnotationWindow(
            image: image,
            captureScaleFactor: scaleFactor,
            displayScaleFactor: editorScaleFactor,
            origin: origin
        )

        window.onCopy = { [weak self, weak window] in
            guard let self, let window else { return }
            let output = self.flattenedOutput(from: window)
            if OutputManager.copyToClipboard(output, scaleFactor: self.lastCaptureScaleFactor) {
                self.confirm("Copied to clipboard")
                self.dismissAnnotationWindow()
            } else {
                OutputManager.showFailure("Copy failed")
            }
        }
        window.onSave = { [weak self, weak window] in
            guard let self, let window else { return }
            let output = self.flattenedOutput(from: window)
            if let url = OutputManager.saveToDefaultLocation(output, scaleFactor: self.lastCaptureScaleFactor) {
                self.confirm("Saved to \(url.lastPathComponent)")
                self.dismissAnnotationWindow()
            } else {
                OutputManager.showFailure("Save failed")
            }
        }
        window.onSaveAs = { [weak self, weak window] in
            guard let self, let window else { return }
            OutputManager.saveWithDialog(self.flattenedOutput(from: window))
        }
        window.onReverseSearch = { [weak self, weak window] in
            guard let self, let window else { return }
            if OutputManager.reverseImageSearch(
                self.flattenedOutput(from: window),
                scaleFactor: self.lastCaptureScaleFactor
            ) {
                self.dismissAnnotationWindow()
            } else {
                OutputManager.showFailure("Reverse image search failed")
            }
        }
        window.onPrint = { [weak self, weak window] in
            guard let self, let window else { return }
            _ = OutputManager.printImage(self.flattenedOutput(from: window))
        }
        window.onShare = { [weak self, weak window] in
            guard let self, let window else { return }
            let output = self.flattenedOutput(from: window)
            let nsImage = NSImage(cgImage: output, size: NSSize(width: output.width, height: output.height))
            let picker = NSSharingServicePicker(items: [nsImage])
            let anchor = window.actionToolbar
            picker.show(relativeTo: anchor.bounds, of: anchor, preferredEdge: .maxY)
        }
        window.onClose = { [weak self] in
            self?.dismissAnnotationWindow()
        }

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        annotationWindow = window
    }

    /// Composite the editor's annotations onto the capture (or return the
    /// capture unchanged) and refresh the last-capture cache once.
    private func flattenedOutput(from window: AnnotationWindow) -> CGImage {
        let output = window.annotationView.annotationManager.composite(onto: window.capturedImage)
            ?? window.capturedImage
        OutputManager.cacheLastCapture(output, scaleFactor: lastCaptureScaleFactor)
        return output
    }

    /// Confirm an output action: a notification when enabled, otherwise a brief
    /// status-item flash so copy/save always acknowledge.
    private func confirm(_ text: String) {
        if PreferencesManager.shared.showNotifications {
            OutputManager.showNotification(title: "Snap", text: text)
        } else {
            statusBarController?.flashSuccess()
        }
    }

    private func dismissAnnotationWindow() {
        annotationWindow?.orderOut(nil)
        annotationWindow = nil
    }

    @objc func saveScreenshot() {
        guard let image = OutputManager.lastCapturedImage else { return }
        if let url = OutputManager.saveToDefaultLocation(image, scaleFactor: OutputManager.lastCapturedScaleFactor) {
            confirm("Saved to \(url.lastPathComponent)")
        } else {
            OutputManager.showFailure("Save failed")
        }
    }

    @objc func saveScreenshotAs() {
        guard let image = OutputManager.lastCapturedImage else { return }
        OutputManager.saveWithDialog(image)
    }
}
