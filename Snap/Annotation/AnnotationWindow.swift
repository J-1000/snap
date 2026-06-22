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
        actionToolbar.onClose = { [weak self] in self?.onClose?() }

        editingToolbar.onToolChanged = { [weak self] tool in
            self?.annotationView.currentTool = tool
        }
        editingToolbar.onColorChanged = { [weak self] color in
            self?.annotationView.currentColor = color
        }
        editingToolbar.onLineWidthChanged = { [weak self] lineWidth in
            self?.annotationView.currentLineWidth = lineWidth
        }
        editingToolbar.onFontSizeChanged = { [weak self] fontSize in
            self?.annotationView.currentFontSize = fontSize
        }
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}
