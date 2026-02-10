import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController?
    private let hotKeyManager = HotKeyManager()

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusBarController = StatusBarController()

        hotKeyManager.onAreaCapture = { [weak self] in
            self?.startAreaCapture()
        }
        hotKeyManager.onFullScreenCapture = { [weak self] in
            self?.startFullScreenCapture()
        }
        hotKeyManager.start()
    }

    func startAreaCapture() {
        // Will be wired in Step 4
    }

    func startFullScreenCapture() {
        // Will be wired in Step 9
    }
}
