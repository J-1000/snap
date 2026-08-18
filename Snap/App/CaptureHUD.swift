import AppKit

/// A small, auto-dismissing floating panel shown after a capture so the shot —
/// and the annotation editor — is always reachable, even when the capture was
/// automatically copied or saved. Click the thumbnail (or Annotate) to open the
/// full editor.
final class CaptureHUD: NSPanel {
    var onAnnotate: (() -> Void)?
    var onCopy: (() -> Void)?
    var onSave: (() -> Void)?
    var onDismiss: (() -> Void)?

    private var dismissWorkItem: DispatchWorkItem?
    private static let thumbWidth: CGFloat = 220
    private static let autoDismissDelay: TimeInterval = 6

    init(image: CGImage, screen: NSScreen? = NSScreen.screens.first) {
        let aspect = CGFloat(image.height) / CGFloat(max(image.width, 1))
        let thumbHeight = min(max(CaptureHUD.thumbWidth * aspect, 70), 180)
        let padding: CGFloat = 10
        let buttonRowHeight: CGFloat = 28
        let spacing: CGFloat = 8
        let width = CaptureHUD.thumbWidth + padding * 2
        let height = thumbHeight + spacing + buttonRowHeight + padding * 2

        super.init(
            contentRect: NSRect(x: 0, y: 0, width: width, height: height),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        isFloatingPanel = true
        level = .floating
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        isReleasedWhenClosed = false
        hidesOnDeactivate = false

        let container = HoverView(frame: NSRect(x: 0, y: 0, width: width, height: height))
        container.material = .hudWindow
        container.state = .active
        container.wantsLayer = true
        container.layer?.cornerRadius = 12
        container.layer?.masksToBounds = true
        container.setAccessibilityElement(true)
        container.setAccessibilityRole(.group)
        container.setAccessibilityLabel("Screenshot actions")
        container.onHoverChange = { [weak self] hovering in
            if hovering { self?.cancelAutoDismiss() } else { self?.scheduleAutoDismiss() }
        }

        // Thumbnail — click to annotate.
        let thumb = NSButton(frame: NSRect(
            x: padding, y: padding + buttonRowHeight + spacing,
            width: CaptureHUD.thumbWidth, height: thumbHeight
        ))
        thumb.isBordered = false
        thumb.bezelStyle = .regularSquare
        thumb.imageScaling = .scaleProportionallyUpOrDown
        thumb.image = NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
        thumb.title = ""
        thumb.target = self
        thumb.action = #selector(annotateTapped)
        thumb.toolTip = "Annotate"
        thumb.setAccessibilityLabel("Annotate captured screenshot")
        thumb.wantsLayer = true
        thumb.layer?.cornerRadius = 6
        thumb.layer?.masksToBounds = true
        container.addSubview(thumb)

        // Action row.
        let row = NSStackView(frame: NSRect(x: padding, y: padding, width: CaptureHUD.thumbWidth, height: buttonRowHeight))
        row.orientation = .horizontal
        row.distribution = .fillEqually
        row.spacing = 6
        row.addArrangedSubview(makeButton("pencil.tip.crop.circle", "Annotate", #selector(annotateTapped)))
        row.addArrangedSubview(makeButton("doc.on.clipboard", "Copy", #selector(copyTapped)))
        row.addArrangedSubview(makeButton("square.and.arrow.down", "Save", #selector(saveTapped)))
        row.addArrangedSubview(makeButton("xmark", "Dismiss", #selector(closeTapped)))
        container.addSubview(row)

        contentView = container
        positionInBottomRight(of: screen)
        scheduleAutoDismiss()
    }

    private func makeButton(_ symbol: String, _ tooltip: String, _ action: Selector) -> NSButton {
        let b = NSButton()
        b.bezelStyle = .recessed
        b.isBordered = true
        b.image = NSImage(systemSymbolName: symbol, accessibilityDescription: tooltip)
        b.imagePosition = .imageOnly
        b.toolTip = tooltip
        b.setAccessibilityLabel(tooltip)
        b.target = self
        b.action = action
        return b
    }

    private func positionInBottomRight(of screen: NSScreen?) {
        guard let screen else { return }
        let vf = screen.visibleFrame
        let margin: CGFloat = 16
        setFrameOrigin(NSPoint(x: vf.maxX - frame.width - margin, y: vf.minY + margin))
    }

    func present() {
        orderFrontRegardless()
    }

    private func scheduleAutoDismiss() {
        cancelAutoDismiss()
        let item = DispatchWorkItem { [weak self] in self?.dismissHUD() }
        dismissWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + CaptureHUD.autoDismissDelay, execute: item)
    }

    private func cancelAutoDismiss() {
        dismissWorkItem?.cancel()
        dismissWorkItem = nil
    }

    private func dismissHUD() {
        cancelAutoDismiss()
        orderOut(nil)
        onDismiss?()
    }

    @objc private func annotateTapped() { dismissHUD(); onAnnotate?() }
    @objc private func copyTapped() { dismissHUD(); onCopy?() }
    @objc private func saveTapped() { dismissHUD(); onSave?() }
    @objc private func closeTapped() { dismissHUD() }
}

/// Visual-effect container that reports hover so the HUD can pause its
/// auto-dismiss while the pointer is over it.
private final class HoverView: NSVisualEffectView {
    var onHoverChange: ((Bool) -> Void)?
    private var hoverTrackingArea: NSTrackingArea?

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = hoverTrackingArea { removeTrackingArea(existing) }
        let area = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways], owner: self)
        addTrackingArea(area)
        hoverTrackingArea = area
    }

    override func mouseEntered(with event: NSEvent) { onHoverChange?(true) }
    override func mouseExited(with event: NSEvent) { onHoverChange?(false) }
}
