import AppKit

final class AnnotationView: NSView {
    private let image: CGImage
    let annotationManager = AnnotationManager()
    var currentTool: AnnotationTool?
    var currentColor: NSColor = .systemRed

    private var dragOrigin: NSPoint?
    private var dragRect: NSRect?
    private var dragEndPoint: NSPoint?
    private var dragPoints: [NSPoint] = []

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
        if currentTool == .line, let start = dragOrigin, let end = dragEndPoint {
            context.saveGState()
            context.translateBy(x: 0, y: bounds.height)
            context.scaleBy(x: 1, y: -1)
            context.setStrokeColor(currentColor.cgColor)
            context.setLineWidth(2.0)
            context.beginPath()
            context.move(to: start)
            context.addLine(to: end)
            context.strokePath()
            context.restoreGState()
        } else if currentTool == .arrow, let start = dragOrigin, let end = dragEndPoint {
            context.saveGState()
            context.translateBy(x: 0, y: bounds.height)
            context.scaleBy(x: 1, y: -1)
            context.setStrokeColor(currentColor.cgColor)
            context.setFillColor(currentColor.cgColor)
            context.setLineWidth(2.0)
            context.beginPath()
            context.move(to: start)
            context.addLine(to: end)
            context.strokePath()
            let angle = atan2(end.y - start.y, end.x - start.x)
            let headSize: CGFloat = 10
            let spread: CGFloat = .pi / 6
            let left = CGPoint(x: end.x - headSize * cos(angle - spread), y: end.y - headSize * sin(angle - spread))
            let right = CGPoint(x: end.x - headSize * cos(angle + spread), y: end.y - headSize * sin(angle + spread))
            context.beginPath()
            context.move(to: end)
            context.addLine(to: left)
            context.addLine(to: right)
            context.closePath()
            context.fillPath()
            context.restoreGState()
        } else if currentTool == .ellipse, let rect = dragRect {
            context.saveGState()
            context.translateBy(x: 0, y: bounds.height)
            context.scaleBy(x: 1, y: -1)
            context.setStrokeColor(currentColor.cgColor)
            context.setLineWidth(2.0)
            context.strokeEllipse(in: rect)
            context.restoreGState()
        } else if let rect = dragRect {
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
        let imagePoint = NSPoint(x: point.x, y: bounds.height - point.y)
        dragOrigin = imagePoint
        dragRect = NSRect(origin: imagePoint, size: .zero)
        if currentTool == .freehand {
            dragPoints = [imagePoint]
        }
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        guard let origin = dragOrigin else { return }
        let point = convert(event.locationInWindow, from: nil)
        let imagePoint = NSPoint(x: point.x, y: bounds.height - point.y)

        dragEndPoint = imagePoint

        if currentTool == .freehand {
            dragPoints.append(imagePoint)
        }

        let x = min(origin.x, imagePoint.x)
        let y = min(origin.y, imagePoint.y)
        let w = abs(imagePoint.x - origin.x)
        let h = abs(imagePoint.y - origin.y)
        dragRect = NSRect(x: x, y: y, width: w, height: h)
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        guard let tool = currentTool else {
            dragOrigin = nil
            dragRect = nil
            dragEndPoint = nil
            needsDisplay = true
            return
        }

        let annotationType = annotationTypeFor(tool)

        if annotationType == .freehand {
            guard dragPoints.count >= 2 else {
                dragOrigin = nil
                dragRect = nil
                dragEndPoint = nil
                dragPoints = []
                needsDisplay = true
                return
            }
            let annotation = Annotation(type: .freehand, points: dragPoints, color: currentColor)
            annotationManager.add(annotation)
        } else if annotationType == .line || annotationType == .arrow {
            guard let start = dragOrigin, let end = dragEndPoint else {
                dragOrigin = nil
                dragRect = nil
                dragEndPoint = nil
                needsDisplay = true
                return
            }
            let dist = hypot(end.x - start.x, end.y - start.y)
            guard dist > 1 else {
                dragOrigin = nil
                dragRect = nil
                dragEndPoint = nil
                needsDisplay = true
                return
            }
            let annotation = Annotation(type: annotationType, start: start, end: end, color: currentColor)
            annotationManager.add(annotation)
        } else {
            guard let rect = dragRect, rect.width > 1, rect.height > 1 else {
                dragOrigin = nil
                dragRect = nil
                dragEndPoint = nil
                needsDisplay = true
                return
            }
            let annotation = Annotation(type: annotationType, rect: rect, color: currentColor)
            annotationManager.add(annotation)
        }

        dragOrigin = nil
        dragRect = nil
        dragEndPoint = nil
        dragPoints = []
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
        case .line: return .line
        case .arrow: return .arrow
        case .freehand: return .freehand
        case .rectangle: return .rectangle
        case .ellipse: return .ellipse
        }
    }
}
