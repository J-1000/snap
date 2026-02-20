import AppKit

final class CaptureEngine {
    private var overlayWindows: [OverlayWindow] = []
    private(set) var isActive = false

    var onImageCaptured: ((CGImage, CGFloat) -> Void)?
    var onCancel: (() -> Void)?
    var onError: ((Error) -> Void)?

    func startAreaSelection() {
        guard !isActive else { return }
        isActive = true
        showOverlays()
    }

    func captureFullScreen(_ screen: NSScreen) {
        Task {
            do {
                let image = try await ScreenCapture.captureFullScreen(screen)
                await MainActor.run {
                    self.onImageCaptured?(image, screen.backingScaleFactor)
                }
            } catch {
                await MainActor.run {
                    self.onError?(error)
                }
            }
        }
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
                // rect is in view coordinates (relative to the overlay window)
                // Convert to global screen coordinates for capture
                let globalRect = NSRect(
                    x: screen.frame.origin.x + rect.origin.x,
                    y: screen.frame.origin.y + rect.origin.y,
                    width: rect.width,
                    height: rect.height
                )
                self?.handleSelectionComplete(rect: globalRect, screen: screen)
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
        Task {
            do {
                let image = try await ScreenCapture.captureRegion(rect, screen: screen)
                await MainActor.run {
                    self.onImageCaptured?(image, screen.backingScaleFactor)
                }
            } catch {
                await MainActor.run {
                    self.onError?(error)
                }
            }
        }
    }
}
