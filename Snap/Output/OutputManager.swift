import AppKit
import UniformTypeIdentifiers

final class OutputManager {

    private(set) static var lastCapturedImage: CGImage?

    static func saveImage(_ image: CGImage) {
        lastCapturedImage = image
    }

    static func copyToClipboard(_ image: CGImage) -> Bool {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        let nsImage = NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
        return pasteboard.writeObjects([nsImage])
    }

    @discardableResult
    static func saveToFile(_ image: CGImage, url: URL? = nil) -> Bool {
        let saveURL = url ?? FileNaming.defaultSaveURL()
        guard let destination = CGImageDestinationCreateWithURL(saveURL as CFURL, kUTTypePNG, 1, nil) else {
            return false
        }
        CGImageDestinationAddImage(destination, image, nil)
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
