import AppKit
import UniformTypeIdentifiers

final class OutputManager {

    private(set) static var lastCapturedImage: CGImage?
    private(set) static var lastCapturedScaleFactor: CGFloat = 1.0

    static func saveImage(_ image: CGImage, scaleFactor: CGFloat = 1.0) {
        lastCapturedImage = image
        lastCapturedScaleFactor = scaleFactor
    }

    static func copyToClipboard(_ image: CGImage, scaleFactor: CGFloat? = nil) -> Bool {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        let outputImage = downscaledImageIfNeeded(image, scaleFactor: scaleFactor)
        let nsImage = NSImage(
            cgImage: outputImage,
            size: NSSize(width: outputImage.width, height: outputImage.height)
        )
        return pasteboard.writeObjects([nsImage])
    }

    @discardableResult
    static func saveToFile(
        _ image: CGImage,
        url: URL? = nil,
        scaleFactor: CGFloat? = nil,
        format: String? = nil,
        jpegQuality: Double? = nil
    ) -> Bool {
        let saveURL = url ?? FileNaming.defaultSaveURL()
        let prefs = PreferencesManager.shared
        let outputFormat = (format ?? prefs.imageFormat).lowercased()
        let quality = jpegQuality ?? prefs.jpegQuality

        let outputType = imageType(for: saveURL, preferredFormat: outputFormat)
        guard let destination = CGImageDestinationCreateWithURL(
            saveURL as CFURL,
            outputType.identifier as CFString,
            1,
            nil
        ) else {
            return false
        }

        let outputImage = downscaledImageIfNeeded(image, scaleFactor: scaleFactor)
        let properties = destinationProperties(for: outputType, jpegQuality: quality)
        CGImageDestinationAddImage(destination, outputImage, properties)
        return CGImageDestinationFinalize(destination)
    }

    static func saveWithDialog(_ image: CGImage) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = FileNaming.defaultFilename()
        panel.allowedContentTypes = [.png, .jpeg]
        panel.canCreateDirectories = true

        panel.begin { response in
            if response == .OK, let url = panel.url {
                if OutputManager.saveToFile(image, url: url) {
                    OutputManager.showNotification(title: "Snap", text: "Saved to \(url.lastPathComponent)")
                }
            }
        }
    }

    private static func imageType(for url: URL, preferredFormat: String) -> UTType {
        if let type = UTType(filenameExtension: url.pathExtension) {
            return type
        }
        return preferredFormat == "jpeg" ? .jpeg : .png
    }

    private static func destinationProperties(for type: UTType, jpegQuality: Double) -> CFDictionary? {
        if type == .jpeg {
            return [kCGImageDestinationLossyCompressionQuality: jpegQuality] as CFDictionary
        }
        return nil
    }

    private static func downscaledImageIfNeeded(_ image: CGImage, scaleFactor: CGFloat?) -> CGImage {
        let prefs = PreferencesManager.shared
        guard prefs.downscaleRetina else { return image }

        let factor = scaleFactor ?? lastCapturedScaleFactor
        guard factor > 1.0 else { return image }

        let newWidth = max(Int(CGFloat(image.width) / factor), 1)
        let newHeight = max(Int(CGFloat(image.height) / factor), 1)
        guard newWidth != image.width || newHeight != image.height else { return image }

        let colorSpace = image.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB)!
        guard let context = CGContext(
            data: nil,
            width: newWidth,
            height: newHeight,
            bitsPerComponent: image.bitsPerComponent,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: image.bitmapInfo.rawValue
        ) else { return image }

        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: newWidth, height: newHeight))
        return context.makeImage() ?? image
    }

    static func showNotification(title: String, text: String) {
        // Use a transient floating panel as notification
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 280, height: 50),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isReleasedWhenClosed = false

        let visualEffect = NSVisualEffectView(frame: panel.contentView!.bounds)
        visualEffect.material = .hudWindow
        visualEffect.state = .active
        visualEffect.wantsLayer = true
        visualEffect.layer?.cornerRadius = 10
        visualEffect.autoresizingMask = [.width, .height]
        panel.contentView?.addSubview(visualEffect)

        let label = NSTextField(labelWithString: text)
        label.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        label.textColor = .white
        label.alignment = .center
        label.frame = visualEffect.bounds
        label.autoresizingMask = [.width, .height]
        visualEffect.addSubview(label)

        // Position at top-center of main screen
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let x = screenFrame.midX - panel.frame.width / 2
            let y = screenFrame.maxY - panel.frame.height - 20
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }

        panel.alphaValue = 0
        panel.orderFrontRegardless()

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2
            panel.animator().alphaValue = 1.0
        }) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                NSAnimationContext.runAnimationGroup({ context in
                    context.duration = 0.3
                    panel.animator().alphaValue = 0.0
                }) {
                    panel.orderOut(nil)
                }
            }
        }
    }
}
