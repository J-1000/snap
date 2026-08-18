@preconcurrency import AppKit
import ScreenCaptureKit

@MainActor
final class CaptureEngine {
    private enum State {
        case idle
        case selecting
        case capturing
    }

    typealias RegionCapture = @MainActor (NSRect, NSScreen) async throws -> CGImage
    typealias FullScreenCapture = @MainActor (NSScreen) async throws -> CGImage
    typealias WindowCapture = @MainActor (SCWindow, WindowCaptureOptions) async throws -> CGImage

    private var overlayWindows: [OverlayWindow] = []
    private var state: State = .idle
    private let regionCapture: RegionCapture
    private let fullScreenCapture: FullScreenCapture
    private let windowCapture: WindowCapture

    var isActive: Bool { state != .idle }

    var onImageCaptured: ((CGImage, CGFloat, NSRect?) -> Void)?
    var onCancel: (() -> Void)?
    var onError: ((Error) -> Void)?

    init(
        regionCapture: @escaping RegionCapture = { rect, screen in
            try await ScreenCapture.captureRegion(rect, screen: screen)
        },
        fullScreenCapture: @escaping FullScreenCapture = { screen in
            try await ScreenCapture.captureFullScreen(screen)
        },
        windowCapture: @escaping WindowCapture = { window, options in
            try await ScreenCapture.captureWindow(window, options: options)
        }
    ) {
        self.regionCapture = regionCapture
        self.fullScreenCapture = fullScreenCapture
        self.windowCapture = windowCapture
    }

    func startAreaSelection() {
        guard state == .idle else { return }
        state = .selecting
        showOverlays()
    }

    func captureFullScreen(_ screen: NSScreen) {
        guard state == .idle else { return }
        state = .capturing
        let scaleFactor = screen.backingScaleFactor
        Task {
            do {
                let image = try await fullScreenCapture(screen)
                state = .idle
                onImageCaptured?(image, scaleFactor, nil)
            } catch {
                state = .idle
                onError?(error)
            }
        }
    }

    func captureWindow(_ window: SCWindow, options: WindowCaptureOptions) {
        guard state == .idle else { return }
        state = .capturing
        let scaleFactor = ScreenCapture.scaleFactor(for: window)
        Task {
            do {
                let image = try await windowCapture(window, options)
                state = .idle
                onImageCaptured?(image, scaleFactor, nil)
            } catch {
                state = .idle
                onError?(error)
            }
        }
    }

    func cancel() {
        guard state == .selecting else { return }
        hideOverlays()
        state = .idle
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

    private func hideOverlays() {
        for window in overlayWindows {
            window.orderOut(nil)
        }
        overlayWindows.removeAll()
    }

    private func handleSelectionComplete(rect: NSRect, screen: NSScreen) {
        guard state == .selecting else { return }
        state = .capturing
        hideOverlays()
        let scaleFactor = screen.backingScaleFactor
        Task {
            do {
                let image = try await regionCapture(rect, screen)
                state = .idle
                onImageCaptured?(image, scaleFactor, rect)
            } catch {
                state = .idle
                onError?(error)
            }
        }
    }
}
