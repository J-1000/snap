import AppKit

final class AnnotationView: NSView, NSTextFieldDelegate {
    private let image: CGImage
    private let captureScaleFactor: CGFloat
    let annotationManager = AnnotationManager()
    var currentTool: AnnotationType?
    var currentColor: NSColor = .systemRed
    var currentLineWidth: CGFloat = 2
    var currentFontSize: CGFloat = 16
    var onHistoryChanged: ((Bool, Bool) -> Void)?

    private var dragOrigin: NSPoint?
    private var dragRect: NSRect?
    private var dragEndPoint: NSPoint?
    private var dragPoints: [NSPoint] = []

    private var activeTextField: NSTextField?
    private var textInsertionPoint: NSPoint? // image coords (top-left origin)
    private var stepBadgeCounter = 0 // resets each time the editor opens
    init(image: CGImage, captureScaleFactor: CGFloat = 1) {
        self.image = image
        self.captureScaleFactor = max(captureScaleFactor, 1)
        super.init(frame: NSRect(x: 0, y: 0, width: CGFloat(image.width), height: CGFloat(image.height)))
        annotationManager.onChanged = { [weak self] in
            guard let self else { return }
            self.needsDisplay = true
            self.onHistoryChanged?(
                self.annotationManager.canUndo,
                self.annotationManager.canRedo
            )
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

        // Captured image, flipped to a top-left origin.
        context.saveGState()
        applyTopLeftFlip(context)
        context.draw(image, in: NSRect(origin: .zero, size: bounds.size))
        context.restoreGState()

        // Committed annotations plus the in-progress drag preview, rendered
        // through the same path so the preview and final output can't drift.
        context.saveGState()
        applyTopLeftFlip(context)
        annotationManager.render(in: context, size: bounds.size, sourceImage: image)
        if let preview = previewAnnotation() {
            annotationManager.render(preview, in: context, size: bounds.size, sourceImage: image)
        }
        context.restoreGState()
    }

    private func applyTopLeftFlip(_ context: CGContext) {
        context.translateBy(x: 0, y: bounds.height)
        context.scaleBy(x: 1, y: -1)
    }

    /// The current drag expressed as a transient Annotation, or nil when there
    /// is nothing to preview.
    private func previewAnnotation() -> Annotation? {
        guard let tool = currentTool else { return nil }
        switch tool {
        case .freehand:
            guard dragPoints.count >= 2 else { return nil }
            return Annotation(type: .freehand, points: dragPoints, color: currentColor, lineWidth: currentLineWidth)
        case .line, .arrow:
            guard let start = dragOrigin, let end = dragEndPoint else { return nil }
            return Annotation(type: tool, start: start, end: end, color: currentColor, lineWidth: currentLineWidth)
        case .rectangle, .ellipse, .blur:
            guard let rect = dragRect, rect.width > 0, rect.height > 0 else { return nil }
            return Annotation(type: tool, rect: rect, color: currentColor, lineWidth: currentLineWidth)
        case .text, .stepBadge:
            return nil
        }
    }

    private func placeStepBadge(at imagePoint: NSPoint) {
        stepBadgeCounter += 1
        let fontSize = imageFontSize
        let diameter = max(fontSize * 1.6, 24 * captureScaleFactor)
        let annotation = Annotation(
            type: .stepBadge,
            badgeNumber: stepBadgeCounter,
            center: imagePoint,
            diameter: diameter,
            color: currentColor
        )
        annotationManager.add(annotation)
    }

    // MARK: - Mouse handling

    override func mouseDown(with event: NSEvent) {
        // Commit any active text input first
        if activeTextField != nil {
            commitActiveText()
        }

        guard currentTool != nil else { return }
        let point = convert(event.locationInWindow, from: nil)
        // Convert from AppKit (bottom-left origin) to image coords (top-left origin)
        let imagePoint = NSPoint(x: point.x, y: bounds.height - point.y)

        if currentTool == .text {
            showTextField(at: point, imagePoint: imagePoint)
            return
        }

        if currentTool == .stepBadge {
            placeStepBadge(at: imagePoint)
            return
        }

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
        var imagePoint = NSPoint(x: point.x, y: bounds.height - point.y)

        let shift = event.modifierFlags.contains(.shift)
        if shift, currentTool == .line || currentTool == .arrow {
            imagePoint = constrainedAngle(from: origin, to: imagePoint)
        }

        dragEndPoint = imagePoint

        if currentTool == .freehand {
            dragPoints.append(imagePoint)
        }

        if shift, currentTool == .rectangle || currentTool == .ellipse || currentTool == .blur {
            dragRect = constrainedSquare(from: origin, to: imagePoint)
        } else {
            let x = min(origin.x, imagePoint.x)
            let y = min(origin.y, imagePoint.y)
            let w = abs(imagePoint.x - origin.x)
            let h = abs(imagePoint.y - origin.y)
            dragRect = NSRect(x: x, y: y, width: w, height: h)
        }
        needsDisplay = true
    }

    /// A square rooted at `origin`, sized by the larger axis toward `current`.
    private func constrainedSquare(from origin: NSPoint, to current: NSPoint) -> NSRect {
        let side = max(abs(current.x - origin.x), abs(current.y - origin.y))
        let x = current.x >= origin.x ? origin.x : origin.x - side
        let y = current.y >= origin.y ? origin.y : origin.y - side
        return NSRect(x: x, y: y, width: side, height: side)
    }

    /// Snap the endpoint to the nearest 45° from `origin`, preserving length.
    private func constrainedAngle(from origin: NSPoint, to current: NSPoint) -> NSPoint {
        let dx = current.x - origin.x
        let dy = current.y - origin.y
        let distance = hypot(dx, dy)
        let snapped = (atan2(dy, dx) / (.pi / 4)).rounded() * (.pi / 4)
        return NSPoint(x: origin.x + distance * cos(snapped), y: origin.y + distance * sin(snapped))
    }

    override func mouseUp(with event: NSEvent) {
        guard let tool = currentTool else {
            dragOrigin = nil
            dragRect = nil
            dragEndPoint = nil
            needsDisplay = true
            return
        }

        let annotationType = tool

        if annotationType == .freehand {
            guard dragPoints.count >= 2 else {
                dragOrigin = nil
                dragRect = nil
                dragEndPoint = nil
                dragPoints = []
                needsDisplay = true
                return
            }
            let annotation = Annotation(type: .freehand, points: dragPoints, color: currentColor, lineWidth: currentLineWidth)
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
            let annotation = Annotation(type: annotationType, start: start, end: end, color: currentColor, lineWidth: currentLineWidth)
            annotationManager.add(annotation)
        } else {
            guard let rect = dragRect, rect.width > 1, rect.height > 1 else {
                dragOrigin = nil
                dragRect = nil
                dragEndPoint = nil
                needsDisplay = true
                return
            }
            let annotation = Annotation(type: annotationType, rect: rect, color: currentColor, lineWidth: currentLineWidth)
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
        // Delete / forward-delete removes the most recent annotation.
        if event.keyCode == 51 || event.keyCode == 117 {
            annotationManager.removeLast()
            return
        }
        super.keyDown(with: event)
    }

    // MARK: - Text input

    /// Font controls are expressed in AppKit points, while annotations are
    /// stored in image pixels. Convert at the original capture scale so text
    /// exports at the selected point size on Retina displays.
    static func imageFontSize(pointSize: CGFloat, captureScaleFactor: CGFloat) -> CGFloat {
        pointSize * max(captureScaleFactor, 1)
    }

    private var imageFontSize: CGFloat {
        Self.imageFontSize(pointSize: currentFontSize, captureScaleFactor: captureScaleFactor)
    }

    private func showTextField(at viewPoint: NSPoint, imagePoint: NSPoint) {
        textInsertionPoint = imagePoint
        let textField = NSTextField()
        textField.font = NSFont.systemFont(ofSize: imageFontSize)
        textField.textColor = currentColor
        textField.backgroundColor = NSColor.white.withAlphaComponent(0.8)
        textField.drawsBackground = true
        textField.isBordered = false
        textField.focusRingType = .none
        textField.isEditable = true
        textField.cell?.wraps = false
        textField.cell?.isScrollable = true
        let fieldHeight = imageFontSize + 8 * captureScaleFactor
        textField.frame = NSRect(
            x: viewPoint.x,
            y: viewPoint.y - fieldHeight,
            width: 200 * captureScaleFactor,
            height: fieldHeight
        )
        textField.delegate = self
        addSubview(textField)
        window?.makeFirstResponder(textField)
        activeTextField = textField
    }

    private func commitActiveText() {
        guard let textField = activeTextField, let insertionPoint = textInsertionPoint else { return }
        let text = textField.stringValue
        if !text.isEmpty {
            let annotation = Annotation(
                type: .text,
                text: text,
                position: insertionPoint,
                fontSize: imageFontSize,
                color: currentColor
            )
            annotationManager.add(annotation)
        }
        textField.removeFromSuperview()
        activeTextField = nil
        textInsertionPoint = nil
        window?.makeFirstResponder(self)
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(insertNewline(_:)) {
            commitActiveText()
            return true
        }
        if commandSelector == #selector(cancelOperation(_:)) {
            // Escape cancels without committing
            activeTextField?.removeFromSuperview()
            activeTextField = nil
            textInsertionPoint = nil
            window?.makeFirstResponder(self)
            return true
        }
        return false
    }
}
