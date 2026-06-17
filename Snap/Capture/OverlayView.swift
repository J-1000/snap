import AppKit

final class OverlayView: NSView {
    var onSelectionComplete: ((NSRect) -> Void)?
    var onCancel: (() -> Void)?

    private enum DragMode {
        case drawing
        case moving(offset: NSPoint)
        case resizing(handle: ResizeHandle)
    }

    private enum ResizeHandle: CaseIterable {
        case topLeft
        case top
        case topRight
        case right
        case bottomRight
        case bottom
        case bottomLeft
        case left
    }

    private var selectionOrigin: NSPoint?
    private var currentSelection: NSRect?
    private var dragMode: DragMode?
    private var resizeAnchor: NSPoint?
    private var resizeOriginalSelection: NSRect?
    private let dimColor = NSColor.black.withAlphaComponent(0.3)
    private let handleSize: CGFloat = 8

    private lazy var dimensionLabel: NSTextField = {
        let label = NSTextField(labelWithString: "")
        label.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .medium)
        label.textColor = .white
        label.backgroundColor = NSColor.black.withAlphaComponent(0.7)
        label.isBezeled = false
        label.isEditable = false
        label.drawsBackground = true
        label.alignment = .center
        label.wantsLayer = true
        label.layer?.cornerRadius = 4
        addSubview(label)
        label.isHidden = true
        return label
    }()

    private lazy var hintLabel: NSTextField = {
        let label = NSTextField(labelWithString: "Return to capture - drag to move - handles resize")
        label.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        label.textColor = .white
        label.backgroundColor = NSColor.black.withAlphaComponent(0.7)
        label.isBezeled = false
        label.isEditable = false
        label.drawsBackground = true
        label.alignment = .center
        label.wantsLayer = true
        label.layer?.cornerRadius = 4
        label.sizeToFit()
        addSubview(label)
        label.isHidden = true
        return label
    }()

    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }

        // Draw dim overlay
        context.setFillColor(dimColor.cgColor)
        context.fill(bounds)

        // Cut out the selection rectangle
        if let selection = currentSelection, selection.width > 0, selection.height > 0 {
            context.setBlendMode(.clear)
            context.fill(selection)
            context.setBlendMode(.normal)

            // Draw selection border
            context.setStrokeColor(NSColor.white.withAlphaComponent(0.8).cgColor)
            context.setLineWidth(1.0)
            context.stroke(selection.insetBy(dx: -0.5, dy: -0.5))

            context.setFillColor(NSColor.white.cgColor)
            context.setStrokeColor(NSColor.black.withAlphaComponent(0.4).cgColor)
            for handleRect in handleRects(for: selection).values {
                context.fill(handleRect)
                context.stroke(handleRect)
            }
        }
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if event.clickCount == 2, let selection = currentSelection, selection.contains(point) {
            completeSelection()
            return
        }

        if let selection = currentSelection, selection.width > 1, selection.height > 1 {
            if let handle = resizeHandle(at: point, in: selection) {
                dragMode = .resizing(handle: handle)
                resizeAnchor = anchorPoint(for: handle, in: selection)
                resizeOriginalSelection = selection
                return
            }
            if selection.contains(point) {
                dragMode = .moving(offset: NSPoint(x: point.x - selection.origin.x, y: point.y - selection.origin.y))
                return
            }
        }

        dragMode = .drawing
        selectionOrigin = point
        currentSelection = NSRect(origin: point, size: .zero)
        dimensionLabel.isHidden = false
        hintLabel.isHidden = true
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        let current = convert(event.locationInWindow, from: nil)

        switch dragMode {
        case .drawing:
            guard let origin = selectionOrigin else { return }
            currentSelection = normalizedRect(from: origin, to: current)
        case .moving(let offset):
            guard let selection = currentSelection else { return }
            let origin = NSPoint(x: current.x - offset.x, y: current.y - offset.y)
            currentSelection = clamped(rect: NSRect(origin: origin, size: selection.size))
        case .resizing:
            guard let anchor = resizeAnchor, let original = resizeOriginalSelection else { return }
            currentSelection = clamped(rect: resizedRect(handle: handleFromDragMode(), original: original, anchor: anchor, current: current))
        case .none:
            return
        }

        updateLabels()
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        dragMode = nil
        resizeAnchor = nil
        resizeOriginalSelection = nil
        guard let selection = currentSelection, selection.width > 1, selection.height > 1 else {
            resetSelection()
            return
        }
        updateLabels()
        needsDisplay = true
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // ESC
            resetSelection()
            onCancel?()
            return
        }
        if event.keyCode == 36 || event.keyCode == 76 || event.keyCode == 49 { // Return, Enter, Space
            completeSelection()
            return
        }
    }

    private func completeSelection() {
        guard let selection = currentSelection, selection.width > 1, selection.height > 1 else { return }
        onSelectionComplete?(selection)
    }

    private func updateLabels() {
        updateDimensionLabel()
        updateHintLabel()
    }

    private func updateDimensionLabel() {
        guard let selection = currentSelection else { return }

        let scaleFactor = window?.backingScaleFactor ?? 1.0
        let pixelWidth = Int(selection.width * scaleFactor)
        let pixelHeight = Int(selection.height * scaleFactor)
        dimensionLabel.stringValue = " \(pixelWidth) × \(pixelHeight) "
        dimensionLabel.sizeToFit()

        // Position label above the top-left corner of the selection
        let labelX = selection.origin.x
        let labelY = selection.maxY + 4
        dimensionLabel.frame.origin = NSPoint(x: labelX, y: labelY)

        // Keep label within view bounds
        if dimensionLabel.frame.maxY > bounds.maxY {
            dimensionLabel.frame.origin.y = selection.origin.y - dimensionLabel.frame.height - 4
        }
        if dimensionLabel.frame.maxX > bounds.maxX {
            dimensionLabel.frame.origin.x = bounds.maxX - dimensionLabel.frame.width
        }
        if dimensionLabel.frame.minX < bounds.minX {
            dimensionLabel.frame.origin.x = bounds.minX
        }
    }

    private func updateHintLabel() {
        guard let selection = currentSelection else { return }
        hintLabel.isHidden = false
        hintLabel.sizeToFit()
        hintLabel.frame.size.width += 14
        hintLabel.frame.size.height += 6

        var x = selection.midX - hintLabel.frame.width / 2
        var y = selection.origin.y - hintLabel.frame.height - 8
        if y < bounds.minY {
            y = selection.maxY + 8
        }
        x = min(max(x, bounds.minX), bounds.maxX - hintLabel.frame.width)
        y = min(max(y, bounds.minY), bounds.maxY - hintLabel.frame.height)
        hintLabel.frame.origin = NSPoint(x: x, y: y)
    }

    private func resetSelection() {
        selectionOrigin = nil
        currentSelection = nil
        dragMode = nil
        resizeAnchor = nil
        resizeOriginalSelection = nil
        dimensionLabel.isHidden = true
        hintLabel.isHidden = true
        needsDisplay = true
    }

    private func normalizedRect(from start: NSPoint, to end: NSPoint) -> NSRect {
        NSRect(
            x: min(start.x, end.x),
            y: min(start.y, end.y),
            width: abs(end.x - start.x),
            height: abs(end.y - start.y)
        )
    }

    private func clamped(rect: NSRect) -> NSRect {
        var rect = rect
        rect.size.width = min(rect.width, bounds.width)
        rect.size.height = min(rect.height, bounds.height)
        rect.origin.x = min(max(rect.origin.x, bounds.minX), bounds.maxX - rect.width)
        rect.origin.y = min(max(rect.origin.y, bounds.minY), bounds.maxY - rect.height)
        return rect
    }

    private func resizeHandle(at point: NSPoint, in selection: NSRect) -> ResizeHandle? {
        handleRects(for: selection).first { $0.value.insetBy(dx: -4, dy: -4).contains(point) }?.key
    }

    private func handleRects(for selection: NSRect) -> [ResizeHandle: NSRect] {
        let half = handleSize / 2
        let points: [ResizeHandle: NSPoint] = [
            .topLeft: NSPoint(x: selection.minX, y: selection.maxY),
            .top: NSPoint(x: selection.midX, y: selection.maxY),
            .topRight: NSPoint(x: selection.maxX, y: selection.maxY),
            .right: NSPoint(x: selection.maxX, y: selection.midY),
            .bottomRight: NSPoint(x: selection.maxX, y: selection.minY),
            .bottom: NSPoint(x: selection.midX, y: selection.minY),
            .bottomLeft: NSPoint(x: selection.minX, y: selection.minY),
            .left: NSPoint(x: selection.minX, y: selection.midY),
        ]
        return points.mapValues { point in
            NSRect(x: point.x - half, y: point.y - half, width: handleSize, height: handleSize)
        }
    }

    private func anchorPoint(for handle: ResizeHandle, in selection: NSRect) -> NSPoint {
        switch handle {
        case .topLeft:
            return NSPoint(x: selection.maxX, y: selection.minY)
        case .top:
            return NSPoint(x: selection.midX, y: selection.minY)
        case .topRight:
            return NSPoint(x: selection.minX, y: selection.minY)
        case .right:
            return NSPoint(x: selection.minX, y: selection.midY)
        case .bottomRight:
            return NSPoint(x: selection.minX, y: selection.maxY)
        case .bottom:
            return NSPoint(x: selection.midX, y: selection.maxY)
        case .bottomLeft:
            return NSPoint(x: selection.maxX, y: selection.maxY)
        case .left:
            return NSPoint(x: selection.maxX, y: selection.midY)
        }
    }

    private func handleFromDragMode() -> ResizeHandle {
        if case .resizing(let handle) = dragMode {
            return handle
        }
        return .bottomRight
    }

    private func resizedRect(handle: ResizeHandle, original: NSRect, anchor: NSPoint, current: NSPoint) -> NSRect {
        switch handle {
        case .topLeft, .topRight, .bottomRight, .bottomLeft:
            return normalizedRect(from: anchor, to: current)
        case .top:
            return normalizedRect(from: NSPoint(x: original.minX, y: original.minY), to: NSPoint(x: original.maxX, y: current.y))
        case .right:
            return normalizedRect(from: NSPoint(x: original.minX, y: original.minY), to: NSPoint(x: current.x, y: original.maxY))
        case .bottom:
            return normalizedRect(from: NSPoint(x: original.minX, y: current.y), to: NSPoint(x: original.maxX, y: original.maxY))
        case .left:
            return normalizedRect(from: NSPoint(x: current.x, y: original.minY), to: NSPoint(x: original.maxX, y: original.maxY))
        }
    }
}
