import AppKit

final class OverlayView: NSView {
    var onSelectionComplete: ((NSRect) -> Void)?
    var onCancel: (() -> Void)?

    private enum DragMode {
        case drawing
        case moving(offset: NSPoint)
        case resizing(handle: ResizeHandle)
    }

    private var selectionOrigin: NSPoint?
    private var currentSelection: NSRect?
    private var dragMode: DragMode?
    private var resizeAnchor: NSPoint?
    private var resizeOriginalSelection: NSRect?
    private let dimColor = NSColor.black.withAlphaComponent(0.3)
    private let handleSize: CGFloat = 8

    private var geometry: SelectionGeometry {
        SelectionGeometry(bounds: bounds, handleSize: handleSize)
    }

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
            for handleRect in geometry.handleRects(for: selection).values {
                context.fill(handleRect)
                context.stroke(handleRect)
            }
        }
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .crosshair)
        guard let selection = currentSelection, selection.width > 1, selection.height > 1 else { return }
        addCursorRect(selection, cursor: .openHand)
        for (handle, rect) in geometry.handleRects(for: selection) {
            addCursorRect(rect.insetBy(dx: -4, dy: -4), cursor: cursor(for: handle))
        }
    }

    private func refreshCursorRects() {
        window?.invalidateCursorRects(for: self)
    }

    private func cursor(for handle: ResizeHandle) -> NSCursor {
        if #available(macOS 15.0, *) {
            let position: NSCursor.FrameResizePosition = switch handle {
            case .top: .top
            case .bottom: .bottom
            case .left: .left
            case .right: .right
            case .topLeft: .topLeft
            case .topRight: .topRight
            case .bottomLeft: .bottomLeft
            case .bottomRight: .bottomRight
            }
            return NSCursor.frameResize(
                position: position,
                directions: [.inward, .outward]
            )
        }

        switch handle {
        case .top, .bottom: return .resizeUpDown
        case .left, .right: return .resizeLeftRight
        case .topLeft, .topRight, .bottomLeft, .bottomRight: return .crosshair
        }
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if event.clickCount == 2, let selection = currentSelection, selection.contains(point) {
            completeSelection()
            return
        }

        if let selection = currentSelection, selection.width > 1, selection.height > 1 {
            if let handle = geometry.resizeHandle(at: point, in: selection) {
                dragMode = .resizing(handle: handle)
                resizeAnchor = geometry.anchorPoint(for: handle, in: selection)
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
        refreshCursorRects()
    }

    override func mouseDragged(with event: NSEvent) {
        let current = convert(event.locationInWindow, from: nil)

        switch dragMode {
        case .drawing:
            guard let origin = selectionOrigin else { return }
            currentSelection = geometry.drawingRect(
                from: origin,
                to: current,
                constrained: event.modifierFlags.contains(.shift)
            )
        case .moving(let offset):
            guard let selection = currentSelection else { return }
            let origin = NSPoint(x: current.x - offset.x, y: current.y - offset.y)
            currentSelection = geometry.clamped(NSRect(origin: origin, size: selection.size))
        case .resizing:
            guard let anchor = resizeAnchor, let original = resizeOriginalSelection else { return }
            currentSelection = geometry.clamped(geometry.resizedRect(handle: handleFromDragMode(), original: original, anchor: anchor, current: current))
        case .none:
            return
        }

        updateLabels()
        needsDisplay = true
        refreshCursorRects()
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
        refreshCursorRects()
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
        // Arrow keys nudge the selection (10px with Shift).
        let step: CGFloat = event.modifierFlags.contains(.shift) ? 10 : 1
        switch event.keyCode {
        case 123: nudgeSelection(dx: -step, dy: 0)
        case 124: nudgeSelection(dx: step, dy: 0)
        case 125: nudgeSelection(dx: 0, dy: -step)
        case 126: nudgeSelection(dx: 0, dy: step)
        default: break
        }
    }

    private func nudgeSelection(dx: CGFloat, dy: CGFloat) {
        guard var selection = currentSelection, selection.width > 1, selection.height > 1 else { return }
        selection.origin.x += dx
        selection.origin.y += dy
        currentSelection = geometry.clamped(selection)
        updateLabels()
        needsDisplay = true
        refreshCursorRects()
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

        let inset: CGFloat = 4
        let w = dimensionLabel.frame.width
        let h = dimensionLabel.frame.height

        // Per the PRD, anchor inside the selection's top-left corner. The hint
        // label lives outside the bottom edge, so the two can't overlap.
        var x = selection.minX + inset
        var y = selection.maxY - h - inset

        // For selections too short to hold the label, place it just above the
        // top edge, dropping just below it only if that would clip the screen.
        if selection.height < h + inset * 2 {
            y = selection.maxY + inset
            if y + h > bounds.maxY {
                y = selection.maxY - h - inset
            }
        }
        x = min(max(x, bounds.minX), bounds.maxX - w)
        dimensionLabel.frame.origin = NSPoint(x: x, y: y)
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
        refreshCursorRects()
    }

    private func handleFromDragMode() -> ResizeHandle {
        if case .resizing(let handle) = dragMode {
            return handle
        }
        return .bottomRight
    }
}
