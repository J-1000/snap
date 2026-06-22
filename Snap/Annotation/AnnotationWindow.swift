import AppKit

final class AnnotationWindow: NSWindow {
    let capturedImage: CGImage
    let annotationView: AnnotationView
    let actionToolbar: ActionToolbar
    let editingToolbar: EditingToolbar

    var onCopy: (() -> Void)?
    var onSave: (() -> Void)?
    var onSaveAs: (() -> Void)?
    var onReverseSearch: (() -> Void)?
    var onPrint: (() -> Void)?
    var onShare: (() -> Void)?
    var onClose: (() -> Void)?

    /// Total window size in points for a capture, including the toolbar margins.
    static func contentSize(for image: CGImage, scaleFactor: CGFloat) -> NSSize {
        let s = max(scaleFactor, 1)
        return NSSize(
            width: CGFloat(image.width) / s + EditingToolbar.width,
            height: CGFloat(image.height) / s + ActionToolbar.height
        )
    }

    init(image: CGImage, scaleFactor: CGFloat, origin: NSPoint) {
        self.capturedImage = image
        self.annotationView = AnnotationView(image: image)
        self.actionToolbar = ActionToolbar()
        self.editingToolbar = EditingToolbar()

        // The captured image is in physical pixels; lay the editor out in points
        // (pixels / scale) and let the Retina backing store render it crisply.
        let s = max(scaleFactor, 1)
        let imageWidth = CGFloat(image.width) / s
        let imageHeight = CGFloat(image.height) / s
        let windowWidth = imageWidth + EditingToolbar.width
        let windowHeight = imageHeight + ActionToolbar.height
        let contentRect = NSRect(origin: origin, size: NSSize(width: windowWidth, height: windowHeight))

        super.init(
            contentRect: contentRect,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )

        level = .floating
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        isReleasedWhenClosed = false
        isMovableByWindowBackground = true

        let container = NSView(frame: NSRect(x: 0, y: 0, width: windowWidth, height: windowHeight))

        // Action toolbar spans full width at bottom
        actionToolbar.frame = NSRect(x: 0, y: 0, width: windowWidth, height: ActionToolbar.height)
        actionToolbar.autoresizingMask = [.width]
        container.addSubview(actionToolbar)

        // Image canvas on the left, sized in points but with a pixel-resolution
        // coordinate system so drawing maps 1 image pixel to 1 device pixel and
        // mouse points convert straight to image-pixel coordinates.
        annotationView.frame = NSRect(x: 0, y: ActionToolbar.height, width: imageWidth, height: imageHeight)
        annotationView.setBoundsSize(NSSize(width: CGFloat(image.width), height: CGFloat(image.height)))
        container.addSubview(annotationView)

        // Editing toolbar on the right
        editingToolbar.frame = NSRect(x: imageWidth, y: ActionToolbar.height, width: EditingToolbar.width, height: imageHeight)
        container.addSubview(editingToolbar)

        contentView = container

        actionToolbar.onCopy = { [weak self] in self?.onCopy?() }
        actionToolbar.onSave = { [weak self] in self?.onSave?() }
        actionToolbar.onSaveAs = { [weak self] in self?.onSaveAs?() }
        actionToolbar.onReverseSearch = { [weak self] in self?.onReverseSearch?() }
        actionToolbar.onPrint = { [weak self] in self?.onPrint?() }
        actionToolbar.onShare = { [weak self] in self?.onShare?() }
        actionToolbar.onClose = { [weak self] in self?.onClose?() }

        editingToolbar.onToolChanged = { [weak self] tool in
            self?.annotationView.currentTool = tool
            PreferencesManager.shared.lastTool = tool?.rawValue
        }
        editingToolbar.onColorChanged = { [weak self] color in
            self?.annotationView.currentColor = color
            PreferencesManager.shared.lastAnnotationColorHex = color.hexString
        }
        editingToolbar.onLineWidthChanged = { [weak self] lineWidth in
            self?.annotationView.currentLineWidth = lineWidth
            PreferencesManager.shared.lastLineWidth = Double(lineWidth)
        }
        editingToolbar.onFontSizeChanged = { [weak self] fontSize in
            self?.annotationView.currentFontSize = fontSize
            PreferencesManager.shared.lastFontSize = Double(fontSize)
        }

        seedAnnotationStyle()
    }

    /// Restore the last-used color, stroke width, font size, and tool so the
    /// editor remembers your settings between captures.
    private func seedAnnotationStyle() {
        let prefs = PreferencesManager.shared
        let color = NSColor(hexString: prefs.lastAnnotationColorHex) ?? .systemRed
        annotationView.currentColor = color
        annotationView.currentLineWidth = CGFloat(prefs.lastLineWidth)
        annotationView.currentFontSize = CGFloat(prefs.lastFontSize)
        editingToolbar.selectedColor = color
        editingToolbar.selectedLineWidth = CGFloat(prefs.lastLineWidth)
        editingToolbar.selectedFontSize = CGFloat(prefs.lastFontSize)
        if let raw = prefs.lastTool, let tool = AnnotationType(rawValue: raw) {
            editingToolbar.selectedTool = tool
            annotationView.currentTool = tool
        }
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

extension NSColor {
    /// `#RRGGBBAA` representation, normalized through sRGB so catalog/dynamic
    /// colors archive without crashing on component access.
    var hexString: String {
        let c = usingColorSpace(.sRGB) ?? self
        let r = Int(round(c.redComponent * 255))
        let g = Int(round(c.greenComponent * 255))
        let b = Int(round(c.blueComponent * 255))
        let a = Int(round(c.alphaComponent * 255))
        return String(format: "#%02X%02X%02X%02X", r, g, b, a)
    }

    convenience init?(hexString: String) {
        var hex = hexString
        if hex.hasPrefix("#") { hex.removeFirst() }
        guard let value = UInt32(hex, radix: 16) else { return nil }
        let r, g, b, a: CGFloat
        switch hex.count {
        case 6:
            r = CGFloat((value >> 16) & 0xFF) / 255
            g = CGFloat((value >> 8) & 0xFF) / 255
            b = CGFloat(value & 0xFF) / 255
            a = 1
        case 8:
            r = CGFloat((value >> 24) & 0xFF) / 255
            g = CGFloat((value >> 16) & 0xFF) / 255
            b = CGFloat((value >> 8) & 0xFF) / 255
            a = CGFloat(value & 0xFF) / 255
        default:
            return nil
        }
        self.init(srgbRed: r, green: g, blue: b, alpha: a)
    }
}
