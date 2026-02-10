import AppKit
import ScreenCaptureKit

final class ScreenCapture: NSObject, SCStreamOutput {

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

    private var stream: SCStream?
    private var continuation: CheckedContinuation<CGImage, Error>?

    static func captureRegion(_ rect: NSRect, screen: NSScreen) async throws -> CGImage {
        let capturer = ScreenCapture()
        return try await capturer.capture(rect: rect, screen: screen)
    }

    static func captureFullScreen(_ screen: NSScreen) async throws -> CGImage {
        return try await captureRegion(screen.frame, screen: screen)
    }

    private func capture(rect: NSRect, screen: NSScreen) async throws -> CGImage {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)

        let screenFrame = screen.frame
        guard let display = content.displays.first(where: { display in
            CGFloat(display.width) == screenFrame.width && CGFloat(display.height) == screenFrame.height
        }) else {
            throw CaptureError.noDisplayFound
        }

        let scaleFactor = screen.backingScaleFactor

        // Convert from view coordinates (origin bottom-left) to screen capture coords
        let sourceRect = CGRect(
            x: rect.origin.x - screenFrame.origin.x,
            y: screenFrame.height - (rect.origin.y - screenFrame.origin.y) - rect.height,
            width: rect.width,
            height: rect.height
        )

        let filter = SCContentFilter(display: display, excludingWindows: [])
        let config = SCStreamConfiguration()
        config.sourceRect = sourceRect
        config.width = Int(rect.width * scaleFactor)
        config.height = Int(rect.height * scaleFactor)
        config.showsCursor = false
        config.capturesAudio = false
        config.minimumFrameInterval = CMTime(value: 1, timescale: 1)

        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation

            let stream = SCStream(filter: filter, configuration: config, delegate: nil)
            self.stream = stream

            do {
                try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: .global())
                stream.startCapture { error in
                    if let error = error {
                        self.continuation?.resume(throwing: error)
                        self.continuation = nil
                    }
                }
            } catch {
                self.continuation?.resume(throwing: error)
                self.continuation = nil
            }
        }
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen else { return }

        stream.stopCapture { _ in }
        self.stream = nil

        guard let imageBuffer = sampleBuffer.imageBuffer else {
            continuation?.resume(throwing: CaptureError.captureFailed)
            continuation = nil
            return
        }

        let ciImage = CIImage(cvImageBuffer: imageBuffer)
        let context = CIContext()
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            continuation?.resume(throwing: CaptureError.captureFailed)
            continuation = nil
            return
        }

        continuation?.resume(returning: cgImage)
        continuation = nil
    }

    static func requestPermission() async -> Bool {
        do {
            _ = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            return true
        } catch {
            return false
        }
    }
}
