import AppKit

final class AnnotationWindow: NSWindow {
    private let capturedImage: CGImage
    private let annotationView: AnnotationView

    init(image: CGImage, screenRect: NSRect) {
        self.capturedImage = image
        self.annotationView = AnnotationView(image: image)

        let contentSize = NSSize(width: CGFloat(image.width), height: CGFloat(image.height))
        let contentRect = NSRect(origin: screenRect.origin, size: contentSize)

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

        contentView = annotationView
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}
