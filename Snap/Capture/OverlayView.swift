import AppKit

final class OverlayView: NSView {
    var onSelectionComplete: ((NSRect) -> Void)?
    var onCancel: (() -> Void)?

    private var selectionOrigin: NSPoint?
    private var currentSelection: NSRect?
    private let dimColor = NSColor.black.withAlphaComponent(0.3)

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
        }
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        selectionOrigin = point
        currentSelection = NSRect(origin: point, size: .zero)
        dimensionLabel.isHidden = false
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        guard let origin = selectionOrigin else { return }
        let current = convert(event.locationInWindow, from: nil)

        let x = min(origin.x, current.x)
        let y = min(origin.y, current.y)
        let width = abs(current.x - origin.x)
        let height = abs(current.y - origin.y)

        currentSelection = NSRect(x: x, y: y, width: width, height: height)
        updateDimensionLabel()
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        guard let selection = currentSelection,
              selection.width > 1, selection.height > 1 else {
            resetSelection()
            return
        }
        onSelectionComplete?(selection)
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // ESC
            resetSelection()
            onCancel?()
        }
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
    }

    private func resetSelection() {
        selectionOrigin = nil
        currentSelection = nil
        dimensionLabel.isHidden = true
        needsDisplay = true
    }
}
