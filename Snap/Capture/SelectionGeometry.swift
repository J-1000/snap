import AppKit

enum ResizeHandle: CaseIterable {
    case topLeft
    case top
    case topRight
    case right
    case bottomRight
    case bottom
    case bottomLeft
    case left
}

/// Pure selection-rectangle geometry, decoupled from the view so the
/// hit-testing, anchors, resize, and clamping math can be unit-tested. All
/// coordinates are in the overlay's bottom-left-origin space.
struct SelectionGeometry {
    let bounds: NSRect
    var handleSize: CGFloat = 8

    func normalizedRect(from start: NSPoint, to end: NSPoint) -> NSRect {
        NSRect(
            x: min(start.x, end.x),
            y: min(start.y, end.y),
            width: abs(end.x - start.x),
            height: abs(end.y - start.y)
        )
    }

    /// A square rooted at `origin`, sized by the larger axis toward `current`.
    func constrainedSquare(from origin: NSPoint, to current: NSPoint) -> NSRect {
        let side = max(abs(current.x - origin.x), abs(current.y - origin.y))
        let x = current.x >= origin.x ? origin.x : origin.x - side
        let y = current.y >= origin.y ? origin.y : origin.y - side
        return NSRect(x: x, y: y, width: side, height: side)
    }

    func clamped(_ rect: NSRect) -> NSRect {
        var rect = rect
        rect.size.width = min(rect.width, bounds.width)
        rect.size.height = min(rect.height, bounds.height)
        rect.origin.x = min(max(rect.origin.x, bounds.minX), bounds.maxX - rect.width)
        rect.origin.y = min(max(rect.origin.y, bounds.minY), bounds.maxY - rect.height)
        return rect
    }

    func handleRects(for selection: NSRect) -> [ResizeHandle: NSRect] {
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

    func resizeHandle(at point: NSPoint, in selection: NSRect) -> ResizeHandle? {
        handleRects(for: selection).first { $0.value.insetBy(dx: -4, dy: -4).contains(point) }?.key
    }

    func anchorPoint(for handle: ResizeHandle, in selection: NSRect) -> NSPoint {
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

    func resizedRect(handle: ResizeHandle, original: NSRect, anchor: NSPoint, current: NSPoint) -> NSRect {
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
