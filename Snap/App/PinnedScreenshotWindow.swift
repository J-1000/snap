import AppKit

/// A user-managed screenshot reference that remains visible above normal app
/// windows and across Spaces until explicitly closed.
final class PinnedScreenshotWindow: NSPanel, NSWindowDelegate {
    let capturedImage: CGImage
    let captureScaleFactor: CGFloat

    var onCopy: (() -> Void)?
    var onSave: (() -> Void)?
    var onClose: (() -> Void)?

    private static let actionBarHeight: CGFloat = 36

    init(image: CGImage, scaleFactor: CGFloat, screen: NSScreen? = NSScreen.main) {
        capturedImage = image
        captureScaleFactor = max(scaleFactor, 1)
        let available = screen?.visibleFrame.size ?? NSSize(width: 1280, height: 800)
        let contentSize = Self.preferredContentSize(
            for: image,
            scaleFactor: captureScaleFactor,
            availableSize: available
        )

        super.init(
            contentRect: NSRect(origin: .zero, size: contentSize),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .utilityWindow],
            backing: .buffered,
            defer: false
        )

        title = "Pinned Screenshot"
        level = .floating
        isFloatingPanel = true
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        contentMinSize = NSSize(width: 240, height: 160)
        delegate = self

        let container = NSView(frame: NSRect(origin: .zero, size: contentSize))

        let imageView = NSImageView(frame: NSRect(
            x: 0,
            y: Self.actionBarHeight,
            width: contentSize.width,
            height: contentSize.height - Self.actionBarHeight
        ))
        imageView.image = NSImage(
            cgImage: image,
            size: NSSize(
                width: CGFloat(image.width) / captureScaleFactor,
                height: CGFloat(image.height) / captureScaleFactor
            )
        )
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.imageAlignment = .alignCenter
        imageView.wantsLayer = true
        imageView.layer?.backgroundColor = NSColor.black.cgColor
        imageView.autoresizingMask = [.width, .height]
        imageView.setAccessibilityLabel("Pinned screenshot preview")
        container.addSubview(imageView)

        let actions = NSStackView(frame: NSRect(
            x: 8,
            y: 4,
            width: contentSize.width - 16,
            height: Self.actionBarHeight - 8
        ))
        actions.orientation = .horizontal
        actions.spacing = 6
        actions.autoresizingMask = [.width]
        actions.addArrangedSubview(makeButton("doc.on.clipboard", "Copy", #selector(copyTapped)))
        actions.addArrangedSubview(makeButton("square.and.arrow.down", "Save", #selector(saveTapped)))
        actions.addArrangedSubview(NSView())
        actions.addArrangedSubview(makeButton("xmark", "Close", #selector(closeTapped)))
        container.addSubview(actions)

        contentView = container
        if let screen {
            let visible = screen.visibleFrame
            setFrameOrigin(NSPoint(
                x: visible.midX - frame.width / 2,
                y: visible.midY - frame.height / 2
            ))
        }
    }

    static func preferredContentSize(
        for image: CGImage,
        scaleFactor: CGFloat,
        availableSize: NSSize
    ) -> NSSize {
        let pointsWide = CGFloat(image.width) / max(scaleFactor, 1)
        let pointsHigh = CGFloat(image.height) / max(scaleFactor, 1)
        let maxWidth = min(720, availableSize.width * 0.7)
        let maxImageHeight = min(540, availableSize.height * 0.7) - actionBarHeight
        let fit = min(1, maxWidth / max(pointsWide, 1), maxImageHeight / max(pointsHigh, 1))
        return NSSize(
            width: max(240, pointsWide * fit),
            height: max(160, pointsHigh * fit + actionBarHeight)
        )
    }

    private func makeButton(_ symbol: String, _ label: String, _ action: Selector) -> NSButton {
        let button = NSButton(title: label, target: self, action: action)
        button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: label)
        button.imagePosition = .imageLeading
        button.bezelStyle = .recessed
        button.setAccessibilityLabel(label)
        return button
    }

    @objc private func copyTapped() { onCopy?() }
    @objc private func saveTapped() { onSave?() }
    @objc private func closeTapped() { close() }

    func windowWillClose(_ notification: Notification) {
        onClose?()
    }
}
