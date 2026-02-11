import AppKit

final class AnnotationView: NSView {
    private let image: CGImage
    var currentTool: AnnotationTool?
    var currentColor: NSColor = .systemRed

    init(image: CGImage) {
        self.image = image
        super.init(frame: NSRect(x: 0, y: 0, width: CGFloat(image.width), height: CGFloat(image.height)))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        context.saveGState()
        // Flip coordinate system so image draws top-left origin
        context.translateBy(x: 0, y: bounds.height)
        context.scaleBy(x: 1, y: -1)
        context.draw(image, in: NSRect(origin: .zero, size: bounds.size))
        context.restoreGState()
    }
}
