import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController?
    private let hotKeyManager = HotKeyManager()
    let captureEngine = CaptureEngine()

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusBarController = StatusBarController()

        captureEngine.onImageCaptured = { image in
            if OutputManager.copyToClipboard(image) {
                OutputManager.showNotification(title: "Snap", text: "Screenshot copied to clipboard")
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
        // Will be wired in Step 9
    }
}
