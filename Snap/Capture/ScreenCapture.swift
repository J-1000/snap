import AppKit
import ScreenCaptureKit

final class ScreenCapture: NSObject, SCStreamOutput, SCStreamDelegate, @unchecked Sendable {

    enum CaptureError: Error, LocalizedError {
        case permissionDenied
        case noDisplayFound
        case captureFailed

        var errorDescription: String? {
            switch self {
            case .permissionDenied:
                return "Screen recording permission is required. Please enable it in System Settings > Privacy & Security > Screen Recording."
            case .noDisplayFound:
                return "No display found for the selected screen."
            case .captureFailed:
                return "Failed to capture the screen region."
            }
        }
    }

    /// Maximum time to wait for a frame before giving up, so a capture can
    /// never wedge the app if no sample buffer ever arrives.
    private static let captureTimeout: TimeInterval = 3

    private var stream: SCStream?
    private var continuation: CheckedContinuation<CGImage, Error>?
    private let lock = NSLock()
    private let sampleHandlerQueue = DispatchQueue(label: "com.snap.ScreenCapture.sampleHandler")
    private var expectedPixelSize: (width: Int, height: Int)?
    private var outputColorSpace: CGColorSpace?

    /// Shared Core Image context with a wide-gamut working space. Reused across
    /// captures — `CIContext` is expensive to construct.
    private static let ciContext = CIContext(options: [
        .workingColorSpace: CGColorSpace(name: CGColorSpace.displayP3) ?? CGColorSpaceCreateDeviceRGB()
    ])

    @MainActor
    static func captureRegion(_ rect: NSRect, screen: NSScreen) async throws -> CGImage {
        let capturer = ScreenCapture()
        return try await capturer.capture(rect: rect, screen: screen)
    }

    @MainActor
    static func captureFullScreen(_ screen: NSScreen) async throws -> CGImage {
        return try await captureRegion(screen.frame, screen: screen)
    }

    /// Find the SCDisplay matching an NSScreen by CGDirectDisplayID
    static func findDisplay(for screen: NSScreen, in displays: [SCDisplay]) -> SCDisplay? {
        let screenNumber = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
        guard let displayID = screenNumber else { return nil }
        return displays.first { $0.displayID == displayID }
    }

    @MainActor
    private func capture(rect: NSRect, screen: NSScreen) async throws -> CGImage {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)

        guard let display = ScreenCapture.findDisplay(for: screen, in: content.displays) else {
            throw CaptureError.noDisplayFound
        }

        let screenFrame = screen.frame
        let scaleFactor = screen.backingScaleFactor

        // Convert from AppKit coordinates (origin bottom-left of primary) to
        // display-local Core Graphics coordinates (origin top-left of this display)
        let sourceRect = CGRect(
            x: rect.origin.x - screenFrame.origin.x,
            y: screenFrame.height - (rect.origin.y - screenFrame.origin.y) - rect.height,
            width: rect.width,
            height: rect.height
        )

        let filter = SCContentFilter(display: display, excludingWindows: [])
        let config = SCStreamConfiguration()
        config.sourceRect = sourceRect
        config.width = Int((rect.width * scaleFactor).rounded())
        config.height = Int((rect.height * scaleFactor).rounded())
        config.showsCursor = PreferencesManager.shared.includeMouseCursor
        config.capturesAudio = false
        config.minimumFrameInterval = CMTime(value: 1, timescale: 1)

        // Capture in the display's native (often Display P3) gamut instead of
        // letting ScreenCaptureKit color-match wide-gamut content down to sRGB.
        let colorSpace = screen.colorSpace?.cgColorSpace
            ?? CGColorSpace(name: CGColorSpace.displayP3)
            ?? CGColorSpaceCreateDeviceRGB()
        if let name = colorSpace.name {
            config.colorSpaceName = name
        }
        config.pixelFormat = kCVPixelFormatType_32BGRA

        // macOS 14+: one-shot capture returns a CGImage directly, skipping the
        // stream / continuation / delegate / timeout plumbing entirely.
        if #available(macOS 14.0, *) {
            let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
            if image.width != config.width || image.height != config.height {
                NSLog("Snap: captured \(image.width)x\(image.height) but requested \(config.width)x\(config.height)")
            }
            return image
        }

        return try await withCheckedThrowingContinuation { continuation in
            let stream = SCStream(filter: filter, configuration: config, delegate: self)

            // Arm under the lock so finish() (called from the sample-handler
            // queue, start-error callback, or timeout) sees these writes.
            lock.lock()
            self.continuation = continuation
            self.stream = stream
            self.expectedPixelSize = (config.width, config.height)
            self.outputColorSpace = colorSpace
            lock.unlock()

            do {
                try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: sampleHandlerQueue)
                stream.startCapture { [weak self] error in
                    if let error = error {
                        self?.finish(.failure(error))
                    }
                }
            } catch {
                finish(.failure(error))
            }

            // Safety net: if no frame ever arrives (display unplugged, throttled,
            // degenerate rect), resolve with an error instead of wedging forever.
            sampleHandlerQueue.asyncAfter(deadline: .now() + Self.captureTimeout) { [weak self] in
                self?.finish(.failure(CaptureError.captureFailed))
            }
        }
    }

    /// Resolve the capture exactly once. Whichever path — frame, start error,
    /// delegate stop, or timeout — arrives first wins; the rest are no-ops.
    /// Also tears down the stream so the SCStream<->self retain cycle can't leak.
    private func finish(_ result: Result<CGImage, Error>) {
        lock.lock()
        guard let continuation = self.continuation else {
            lock.unlock()
            return
        }
        self.continuation = nil
        let stream = self.stream
        self.stream = nil
        let expected = self.expectedPixelSize
        self.expectedPixelSize = nil
        lock.unlock()

        if case .success(let image) = result, let expected,
           image.width != expected.width || image.height != expected.height {
            NSLog("Snap: captured \(image.width)x\(image.height) but requested \(expected.width)x\(expected.height)")
        }

        stream?.stopCapture { _ in }
        continuation.resume(with: result)
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen else { return }

        guard let imageBuffer = sampleBuffer.imageBuffer else {
            finish(.failure(CaptureError.captureFailed))
            return
        }

        let ciImage = CIImage(cvImageBuffer: imageBuffer)
        lock.lock()
        let colorSpace = outputColorSpace ?? CGColorSpaceCreateDeviceRGB()
        lock.unlock()
        guard let cgImage = Self.ciContext.createCGImage(
            ciImage, from: ciImage.extent, format: .RGBA8, colorSpace: colorSpace
        ) else {
            finish(.failure(CaptureError.captureFailed))
            return
        }

        finish(.success(cgImage))
    }

    func stream(_ stream: SCStream, didStopWithError error: Error) {
        finish(.failure(error))
    }

    static func requestPermission() async -> Bool {
        do {
            _ = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            return true
        } catch {
            return false
        }
    }

    /// Whether Snap currently has Screen Recording permission (does not prompt).
    static func hasScreenRecordingPermission() -> Bool {
        CGPreflightScreenCaptureAccess()
    }

    /// Trigger the system Screen Recording prompt and add Snap to the Privacy
    /// list. Returns whether access is granted.
    @discardableResult
    static func requestScreenRecordingPermission() -> Bool {
        CGRequestScreenCaptureAccess()
    }
}
