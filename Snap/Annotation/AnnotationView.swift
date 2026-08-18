import AppKit

final class AnnotationView: NSView, NSTextFieldDelegate {
    private let image: CGImage
    private let captureScaleFactor: CGFloat
    let annotationManager = AnnotationManager()
    var currentTool: AnnotationType? {
        didSet {
            if currentTool != nil {
                selectAnnotation(nil)
            }
        }
    }
    var currentColor: NSColor = .systemRed
    var currentLineWidth: CGFloat = 2
    var currentFontSize: CGFloat = 16
    var onHistoryChanged: ((Bool, Bool) -> Void)?
    var onSelectionChanged: ((Annotation?) -> Void)?

    private(set) var selectedAnnotationID: UUID?

    private enum SelectionInteraction {
        case moving(id: UUID, start: NSPoint, original: Annotation)
        case resizing(id: UUID, handle: ResizeHandle, anchor: NSPoint, original: Annotation)
    }

    private var dragOrigin: NSPoint?
    private var dragRect: NSRect?
    private var dragEndPoint: NSPoint?
    private var dragPoints: [NSPoint] = []
    private var selectionInteraction: SelectionInteraction?
    private var selectionDidChange = false

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
            if let selectedID = self.selectedAnnotationID,
               self.annotationManager.annotation(withID: selectedID) == nil {
                self.selectAnnotation(nil)
            }
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
        drawSelection(in: context)
        context.restoreGState()
    }

    private var selectionHandleSize: CGFloat { 8 * captureScaleFactor }

    private var selectionGeometry: SelectionGeometry {
        SelectionGeometry(bounds: bounds, handleSize: selectionHandleSize)
    }

    private func drawSelection(in context: CGContext) {
        guard let selectedAnnotationID,
              let annotation = annotationManager.annotation(withID: selectedAnnotationID) else {
            return
        }
        let rect = annotation.rect.insetBy(dx: -3 * captureScaleFactor, dy: -3 * captureScaleFactor)
        context.setStrokeColor(NSColor.controlAccentColor.cgColor)
        context.setLineWidth(max(captureScaleFactor, 1))
        context.setLineDash(phase: 0, lengths: [5 * captureScaleFactor, 3 * captureScaleFactor])
        context.stroke(rect)
        context.setLineDash(phase: 0, lengths: [])
        context.setFillColor(NSColor.white.cgColor)
        for handle in selectionGeometry.handleRects(for: rect).values {
            context.fill(handle)
            context.stroke(handle)
        }
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
        case .rectangle, .ellipse, .blur, .redact:
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

        let point = convert(event.locationInWindow, from: nil)
        // Convert from AppKit (bottom-left origin) to image coords (top-left origin)
        let imagePoint = NSPoint(x: point.x, y: bounds.height - point.y)

        guard currentTool != nil else {
            beginSelectionInteraction(at: imagePoint)
            return
        }

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
        let point = convert(event.locationInWindow, from: nil)
        var imagePoint = NSPoint(x: point.x, y: bounds.height - point.y)

        if updateSelectionInteraction(to: imagePoint) {
            return
        }

        guard let origin = dragOrigin else { return }

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
        if selectionInteraction != nil {
            if selectionDidChange {
                annotationManager.commitTransaction()
            } else {
                annotationManager.cancelTransaction()
            }
            selectionInteraction = nil
            selectionDidChange = false
            return
        }

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
            case "d":
                duplicateSelectedAnnotation()
                return
            case "]":
                bringSelectedAnnotationForward()
                return
            case "[":
                sendSelectedAnnotationBackward()
                return
            default:
                break
            }
        }
        if event.keyCode == 53, selectedAnnotationID != nil {
            selectAnnotation(nil)
            return
        }
        if let selectedAnnotationID, [123, 124, 125, 126].contains(event.keyCode) {
            let distance: CGFloat = event.modifierFlags.contains(.shift) ? 10 : 1
            let offset: NSPoint = switch event.keyCode {
            case 123: NSPoint(x: -distance, y: 0)
            case 124: NSPoint(x: distance, y: 0)
            case 125: NSPoint(x: 0, y: distance)
            default: NSPoint(x: 0, y: -distance)
            }
            if let annotation = annotationManager.annotation(withID: selectedAnnotationID) {
                _ = annotationManager.replace(clampedTranslation(of: annotation, x: offset.x, y: offset.y))
            }
            return
        }
        // Delete / forward-delete removes the selection, or the most recent annotation.
        if event.keyCode == 51 || event.keyCode == 117 {
            if let selectedAnnotationID {
                annotationManager.remove(id: selectedAnnotationID)
                selectAnnotation(nil)
            } else {
                annotationManager.removeLast()
            }
            return
        }
        super.keyDown(with: event)
    }

    func recolorSelectedAnnotation(_ color: NSColor) {
        guard let selectedAnnotationID else { return }
        annotationManager.recolor(id: selectedAnnotationID, color: color)
    }

    @objc func duplicateSelectedAnnotation() {
        guard let selectedAnnotationID,
              let newID = annotationManager.duplicate(
                id: selectedAnnotationID,
                offset: 12 * captureScaleFactor
              ) else { return }
        selectAnnotation(newID)
    }

    @objc func bringSelectedAnnotationForward() {
        guard let selectedAnnotationID else { return }
        annotationManager.bringForward(id: selectedAnnotationID)
    }

    @objc func sendSelectedAnnotationBackward() {
        guard let selectedAnnotationID else { return }
        annotationManager.sendBackward(id: selectedAnnotationID)
    }

    @objc func deleteSelectedAnnotation() {
        guard let selectedAnnotationID else { return }
        annotationManager.remove(id: selectedAnnotationID)
        selectAnnotation(nil)
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        let point = convert(event.locationInWindow, from: nil)
        let imagePoint = NSPoint(x: point.x, y: bounds.height - point.y)
        if let annotation = annotationManager.annotation(
            at: imagePoint,
            tolerance: 8 * captureScaleFactor
        ) {
            selectAnnotation(annotation.id)
        }
        guard selectedAnnotationID != nil else { return nil }
        let menu = NSMenu()
        menu.addItem(withTitle: "Duplicate", action: #selector(duplicateSelectedAnnotation), keyEquivalent: "")
        menu.addItem(withTitle: "Bring Forward", action: #selector(bringSelectedAnnotationForward), keyEquivalent: "")
        menu.addItem(withTitle: "Send Backward", action: #selector(sendSelectedAnnotationBackward), keyEquivalent: "")
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "Delete", action: #selector(deleteSelectedAnnotation), keyEquivalent: "")
        for item in menu.items { item.target = self }
        return menu
    }

    private func beginSelectionInteraction(at point: NSPoint) {
        if let selectedAnnotationID,
           let selected = annotationManager.annotation(withID: selectedAnnotationID) {
            let selectionRect = selected.rect.insetBy(dx: -3 * captureScaleFactor, dy: -3 * captureScaleFactor)
            if let handle = selectionGeometry.resizeHandle(at: point, in: selectionRect) {
                annotationManager.beginTransaction()
                selectionInteraction = .resizing(
                    id: selectedAnnotationID,
                    handle: handle,
                    anchor: selectionGeometry.anchorPoint(for: handle, in: selected.rect),
                    original: selected
                )
                selectionDidChange = false
                return
            }
        }

        guard let hit = annotationManager.annotation(at: point, tolerance: 8 * captureScaleFactor) else {
            selectAnnotation(nil)
            return
        }
        selectAnnotation(hit.id)
        annotationManager.beginTransaction()
        selectionInteraction = .moving(id: hit.id, start: point, original: hit)
        selectionDidChange = false
    }

    private func updateSelectionInteraction(to point: NSPoint) -> Bool {
        guard let selectionInteraction else { return false }
        let updated: Annotation
        switch selectionInteraction {
        case .moving(_, let start, let original):
            updated = clampedTranslation(
                of: original,
                x: point.x - start.x,
                y: point.y - start.y
            )
        case .resizing(_, let handle, let anchor, let original):
            let resizedRect = selectionGeometry.resizedRect(
                handle: handle,
                original: original.rect,
                anchor: anchor,
                current: point
            )
            updated = original.resized(to: selectionGeometry.clamped(resizedRect))
        }
        selectionDidChange = true
        annotationManager.replace(updated)
        return true
    }

    private func clampedTranslation(of annotation: Annotation, x: CGFloat, y: CGFloat) -> Annotation {
        let proposed = annotation.translatedBy(x: x, y: y)
        let clampedRect = selectionGeometry.clamped(proposed.rect)
        return annotation.translatedBy(
            x: clampedRect.minX - annotation.rect.minX,
            y: clampedRect.minY - annotation.rect.minY
        )
    }

    private func selectAnnotation(_ id: UUID?) {
        selectedAnnotationID = id
        let annotation = id.flatMap(annotationManager.annotation(withID:))
        onSelectionChanged?(annotation)
        needsDisplay = true
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
