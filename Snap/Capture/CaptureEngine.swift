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

    @discardableResult
    func repeatLastAreaCapture() -> Bool {
        guard state == .idle,
              let savedArea = PreferencesManager.shared.lastAreaCapture,
              let screen = Self.screen(for: savedArea, in: NSScreen.screens),
              let rect = Self.clampedCaptureRect(savedArea.rect, to: screen.frame) else {
            return false
        }
        captureRegion(rect, screen: screen)
        return true
    }

    static func clampedCaptureRect(_ rect: NSRect, to screenFrame: NSRect) -> NSRect? {
        guard rect.width > 1, rect.height > 1,
              screenFrame.width > 1, screenFrame.height > 1 else {
            return nil
        }
        let size = NSSize(
            width: min(rect.width, screenFrame.width),
            height: min(rect.height, screenFrame.height)
        )
        let origin = NSPoint(
            x: min(max(rect.minX, screenFrame.minX), screenFrame.maxX - size.width),
            y: min(max(rect.minY, screenFrame.minY), screenFrame.maxY - size.height)
        )
        return NSRect(origin: origin, size: size)
    }

    private static func screen(for savedArea: SavedCaptureArea, in screens: [NSScreen]) -> NSScreen? {
        screens.first { ScreenCapture.displayID(for: $0) == savedArea.displayID }
            ?? screens.first { $0.frame.intersects(savedArea.rect) }
            ?? screens.first
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
        hideOverlays()
        captureRegion(rect, screen: screen)
    }

    private func captureRegion(_ rect: NSRect, screen: NSScreen) {
        guard state == .idle || state == .selecting else { return }
        state = .capturing
        let scaleFactor = screen.backingScaleFactor
        Task {
            do {
                let image = try await regionCapture(rect, screen)
                if let displayID = ScreenCapture.displayID(for: screen) {
                    PreferencesManager.shared.lastAreaCapture = SavedCaptureArea(
                        rect: rect,
                        displayID: displayID
                    )
                }
                state = .idle
                onImageCaptured?(image, scaleFactor, rect)
            } catch {
                state = .idle
                onError?(error)
            }
        }
    }
}
