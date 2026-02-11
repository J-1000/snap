import AppKit

final class AnnotationWindow: NSWindow {
    let capturedImage: CGImage
    let annotationView: AnnotationView
    let actionToolbar: ActionToolbar
    let editingToolbar: EditingToolbar

    var onCopy: (() -> Void)?
    var onSave: (() -> Void)?
    var onSaveAs: (() -> Void)?
    var onClose: (() -> Void)?

    init(image: CGImage, screenRect: NSRect) {
        self.capturedImage = image
        self.annotationView = AnnotationView(image: image)
        self.actionToolbar = ActionToolbar()
        self.editingToolbar = EditingToolbar()

        let imageWidth = CGFloat(image.width)
        let imageHeight = CGFloat(image.height)
        let windowWidth = imageWidth + EditingToolbar.width
        let windowHeight = imageHeight + ActionToolbar.height
        let contentRect = NSRect(origin: screenRect.origin, size: NSSize(width: windowWidth, height: windowHeight))

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

        // Image canvas on the left
        annotationView.frame = NSRect(x: 0, y: ActionToolbar.height, width: imageWidth, height: imageHeight)
        container.addSubview(annotationView)

        // Editing toolbar on the right
        editingToolbar.frame = NSRect(x: imageWidth, y: ActionToolbar.height, width: EditingToolbar.width, height: imageHeight)
        container.addSubview(editingToolbar)

        contentView = container

        actionToolbar.onCopy = { [weak self] in self?.onCopy?() }
        actionToolbar.onSave = { [weak self] in self?.onSave?() }
        actionToolbar.onSaveAs = { [weak self] in self?.onSaveAs?() }
        actionToolbar.onClose = { [weak self] in self?.onClose?() }

        editingToolbar.onToolChanged = { [weak self] tool in
            self?.annotationView.currentTool = tool
        }
        editingToolbar.onColorChanged = { [weak self] color in
            self?.annotationView.currentColor = color
        }
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}
