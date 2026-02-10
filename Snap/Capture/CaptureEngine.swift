import AppKit

final class CaptureEngine {
    private var overlayWindows: [OverlayWindow] = []
    private(set) var isActive = false

    var onCaptureComplete: ((NSRect, NSScreen) -> Void)?
    var onCancel: (() -> Void)?

    func startAreaSelection() {
        guard !isActive else { return }
        isActive = true
        showOverlays()
    }

    func cancel() {
        dismissOverlays()
        onCancel?()
    }

    private func showOverlays() {
        for screen in NSScreen.screens {
            let window = OverlayWindow(screen: screen)
            let overlayView = OverlayView()
            overlayView.onSelectionComplete = { [weak self] rect in
                self?.handleSelectionComplete(rect: rect, screen: screen)
            }
            overlayView.onCancel = { [weak self] in
                self?.cancel()
            }
            window.contentView = overlayView
            window.makeKeyAndOrderFront(nil)
            overlayWindows.append(window)
        }

        NSApp.activate(ignoringOtherApps: true)
        overlayWindows.first?.makeKey()
    }

    func dismissOverlays() {
        for window in overlayWindows {
            window.orderOut(nil)
        }
        overlayWindows.removeAll()
        isActive = false
    }

    private func handleSelectionComplete(rect: NSRect, screen: NSScreen) {
        dismissOverlays()
        onCaptureComplete?(rect, screen)
    }
}
