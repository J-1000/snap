import AppKit
import UniformTypeIdentifiers

@MainActor
final class OutputManager {

    private(set) static var lastCapturedImage: CGImage?
    private(set) static var lastCapturedScaleFactor: CGFloat = 1.0
    private static var clearWorkItem: DispatchWorkItem?

    /// How long to keep the last capture resident for the "Save Last" menu items
    /// before releasing it, so the idle menu-bar process doesn't hold a
    /// full-resolution image (up to ~33 MB for a 4K grab) indefinitely.
    private static let retentionInterval: TimeInterval = 120

    /// Cache the latest capture/output for the "Save Last" menu items. This
    /// does not write to disk — see `saveToFile`/`saveToDefaultLocation`.
    static func cacheLastCapture(_ image: CGImage, scaleFactor: CGFloat = 1.0) {
        lastCapturedImage = image
        lastCapturedScaleFactor = scaleFactor
        scheduleClearLastCapture()
    }

    private static func scheduleClearLastCapture() {
        clearWorkItem?.cancel()
        let item = DispatchWorkItem { lastCapturedImage = nil }
        clearWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + retentionInterval, execute: item)
    }

    static func copyToClipboard(_ image: CGImage, scaleFactor: CGFloat? = nil) -> Bool {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        let outputImage = downscaledImageIfNeeded(image, scaleFactor: scaleFactor)
        let item = NSPasteboardItem()

        // Offer PNG first — most targets (web forms, Slack/Discord, Google
        // Images) prefer or require it — with TIFF for AppKit-native consumers.
        if let png = pngData(from: outputImage) {
            item.setData(png, forType: .png)
        }
        let nsImage = NSImage(
            cgImage: outputImage,
            size: NSSize(width: outputImage.width, height: outputImage.height)
        )
        if let tiff = nsImage.tiffRepresentation {
            item.setData(tiff, forType: .tiff)
        }
        guard !item.types.isEmpty else { return false }
        return pasteboard.writeObjects([item])
    }

    private static func pngData(from image: CGImage) -> Data? {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data, UTType.png.identifier as CFString, 1, nil
        ) else {
            return nil
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return data as Data
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

    /// Save to the user's configured directory and format with an
    /// auto-generated filename. Returns the destination URL on success. Shared
    /// by the capture flow, the editor's Save button, and the menu-bar item so
    /// they can't drift apart.
    @discardableResult
    static func saveToDefaultLocation(_ image: CGImage, scaleFactor: CGFloat? = nil) -> URL? {
        let prefs = PreferencesManager.shared
        let url = prefs.saveDirectory.appendingPathComponent(
            FileNaming.defaultFilename(extension: prefs.imageFormat))
        guard saveToFile(
            image, url: url, scaleFactor: scaleFactor,
            format: prefs.imageFormat, jpegQuality: prefs.jpegQuality
        ) else {
            return nil
        }
        return url
    }

    static func saveWithDialog(_ image: CGImage) {
        let panel = NSSavePanel()
        let prefs = PreferencesManager.shared
        panel.nameFieldStringValue = FileNaming.defaultFilename(extension: prefs.imageFormat)
        panel.allowedContentTypes = [.png, .jpeg]
        panel.canCreateDirectories = true

        panel.begin { response in
            if response == .OK, let url = panel.url {
                if OutputManager.saveToFile(image, url: url) {
                    OutputManager.showNotification(title: "Snap", text: "Saved to \(url.lastPathComponent)")
                } else {
                    OutputManager.showFailure("Could not save \(url.lastPathComponent)")
                }
            }
        }
    }

    static func printImage(_ image: CGImage) -> Bool {
        let nsImage = NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
        let imageView = NSImageView(frame: NSRect(x: 0, y: 0, width: nsImage.size.width, height: nsImage.size.height))
        imageView.image = nsImage
        imageView.imageScaling = .scaleProportionallyUpOrDown

        let printInfo = NSPrintInfo.shared
        printInfo.horizontalPagination = .fit
        printInfo.verticalPagination = .fit
        printInfo.isHorizontallyCentered = true
        printInfo.isVerticallyCentered = true

        let operation = NSPrintOperation(view: imageView, printInfo: printInfo)
        operation.showsPrintPanel = true
        operation.showsProgressPanel = true
        return operation.run()
    }

    @discardableResult
    static func reverseImageSearch(_ image: CGImage, scaleFactor: CGFloat? = nil) -> Bool {
        guard copyToClipboard(image, scaleFactor: scaleFactor),
              let url = URL(string: "https://images.google.com/") else {
            return false
        }
        NSWorkspace.shared.open(url)
        showNotification(title: "Snap", text: "Image copied. Paste it into Google Images.")
        return true
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
        showNotification(title: title, text: text, respectingPreference: true)
    }

    /// Failures must remain visible even when optional success notifications
    /// are disabled; otherwise a failed output action appears to do nothing.
    static func showFailure(_ text: String) {
        showNotification(title: "Snap", text: text, respectingPreference: false)
    }

    private static func showNotification(
        title: String,
        text: String,
        respectingPreference: Bool
    ) {
        guard !respectingPreference || PreferencesManager.shared.showNotifications else { return }

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
                    // AppKit invokes animation completions on the main thread,
                    // but the legacy closure type does not carry that annotation.
                    MainActor.assumeIsolated {
                        panel.orderOut(nil)
                    }
                }
            }
        }
    }
}
