import AppKit

final class AnnotationView: NSView {
    private let image: CGImage
    let annotationManager = AnnotationManager()
    var currentTool: AnnotationTool?
    var currentColor: NSColor = .systemRed

    private var dragOrigin: NSPoint?
    private var dragRect: NSRect?

    init(image: CGImage) {
        self.image = image
        super.init(frame: NSRect(x: 0, y: 0, width: CGFloat(image.width), height: CGFloat(image.height)))
        annotationManager.onChanged = { [weak self] in
            self?.needsDisplay = true
        }
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

        // Draw the captured image (flipped to top-left origin)
        context.saveGState()
        context.translateBy(x: 0, y: bounds.height)
        context.scaleBy(x: 1, y: -1)
        context.draw(image, in: NSRect(origin: .zero, size: bounds.size))
        context.restoreGState()

        // Draw committed annotations (in top-left origin coordinate system)
        context.saveGState()
        context.translateBy(x: 0, y: bounds.height)
        context.scaleBy(x: 1, y: -1)
        annotationManager.render(in: context, size: bounds.size)
        context.restoreGState()

        // Draw live preview of current drag
        if let rect = dragRect {
            context.saveGState()
            context.translateBy(x: 0, y: bounds.height)
            context.scaleBy(x: 1, y: -1)
            context.setStrokeColor(currentColor.cgColor)
            context.setLineWidth(2.0)
            context.stroke(rect)
            context.restoreGState()
        }
    }

    // MARK: - Mouse handling

    override func mouseDown(with event: NSEvent) {
        guard currentTool != nil else { return }
        let point = convert(event.locationInWindow, from: nil)
        // Convert from AppKit (bottom-left origin) to image coords (top-left origin)
        dragOrigin = NSPoint(x: point.x, y: bounds.height - point.y)
        dragRect = NSRect(origin: dragOrigin!, size: .zero)
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        guard let origin = dragOrigin else { return }
        let point = convert(event.locationInWindow, from: nil)
        let imagePoint = NSPoint(x: point.x, y: bounds.height - point.y)

        let x = min(origin.x, imagePoint.x)
        let y = min(origin.y, imagePoint.y)
        let w = abs(imagePoint.x - origin.x)
        let h = abs(imagePoint.y - origin.y)
        dragRect = NSRect(x: x, y: y, width: w, height: h)
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        guard let rect = dragRect, let tool = currentTool,
              rect.width > 1, rect.height > 1 else {
            dragOrigin = nil
            dragRect = nil
            needsDisplay = true
            return
        }

        let annotation = Annotation(type: annotationTypeFor(tool), rect: rect, color: currentColor)
        annotationManager.add(annotation)
        dragOrigin = nil
        dragRect = nil
    }

    // MARK: - Key handling

    override func keyDown(with event: NSEvent) {
        if event.modifierFlags.contains(.command) {
            switch event.charactersIgnoringModifiers {
            case "z":
                if event.modifierFlags.contains(.shift) {
                    annotationManager.redo()
                } else {
                    annotationManager.undo()
                }
                return
            default:
                break
            }
        }
        super.keyDown(with: event)
    }

    private func annotationTypeFor(_ tool: AnnotationTool) -> AnnotationType {
        switch tool {
        case .rectangle: return .rectangle
        }
    }
}
