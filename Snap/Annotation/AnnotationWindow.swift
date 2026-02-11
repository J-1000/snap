import AppKit

final class AnnotationWindow: NSWindow {
    let capturedImage: CGImage
    let annotationView: AnnotationView
    let actionToolbar: ActionToolbar

    var onCopy: (() -> Void)?
    var onSave: (() -> Void)?
    var onSaveAs: (() -> Void)?
    var onClose: (() -> Void)?

    init(image: CGImage, screenRect: NSRect) {
        self.capturedImage = image
        self.annotationView = AnnotationView(image: image)
        self.actionToolbar = ActionToolbar()

        let imageWidth = CGFloat(image.width)
        let imageHeight = CGFloat(image.height)
        let windowWidth = imageWidth
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

        actionToolbar.frame = NSRect(x: 0, y: 0, width: windowWidth, height: ActionToolbar.height)
        actionToolbar.autoresizingMask = [.width]
        container.addSubview(actionToolbar)

        annotationView.frame = NSRect(x: 0, y: ActionToolbar.height, width: imageWidth, height: imageHeight)
        annotationView.autoresizingMask = [.width]
        container.addSubview(annotationView)

        contentView = container

        actionToolbar.onCopy = { [weak self] in self?.onCopy?() }
        actionToolbar.onSave = { [weak self] in self?.onSave?() }
        actionToolbar.onSaveAs = { [weak self] in self?.onSaveAs?() }
        actionToolbar.onClose = { [weak self] in self?.onClose?() }
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}
