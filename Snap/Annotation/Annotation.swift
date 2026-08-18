import AppKit
import Foundation

enum AnnotationType: String, CaseIterable {
    // Declaration order is the editing-toolbar order.
    case line
    case arrow
    case freehand
    case rectangle
    case ellipse
    case text
    case blur
    case redact
    case stepBadge

    var toolbarSymbol: String {
        switch self {
        case .line: return "line.diagonal"
        case .arrow: return "arrow.up.right"
        case .freehand: return "scribble"
        case .rectangle: return "rectangle"
        case .ellipse: return "oval"
        case .text: return "textformat"
        case .blur: return "square.grid.3x3"
        case .redact: return "rectangle.fill"
        case .stepBadge: return "1.circle.fill"
        }
    }

    var tooltip: String {
        switch self {
        case .line: return "Line"
        case .arrow: return "Arrow"
        case .freehand: return "Freehand"
        case .rectangle: return "Rectangle"
        case .ellipse: return "Ellipse"
        case .text: return "Text"
        case .blur: return "Blur / Pixelate"
        case .redact: return "Solid Redaction"
        case .stepBadge: return "Step Badge"
        }
    }
}

struct Annotation {
    private(set) var id: UUID
    let type: AnnotationType
    var rect: NSRect
    var startPoint: NSPoint?
    var endPoint: NSPoint?
    var points: [NSPoint]?
    var text: String?
    var fontSize: CGFloat?
    var color: NSColor
    var lineWidth: CGFloat

    init(type: AnnotationType, rect: NSRect, color: NSColor, lineWidth: CGFloat = 2.0) {
        self.id = UUID()
        self.type = type
        self.rect = rect
        self.color = color
        self.lineWidth = lineWidth
    }

    init(type: AnnotationType, start: NSPoint, end: NSPoint, color: NSColor, lineWidth: CGFloat = 2.0) {
        self.id = UUID()
        self.type = type
        self.startPoint = start
        self.endPoint = end
        self.rect = NSRect(
            x: min(start.x, end.x),
            y: min(start.y, end.y),
            width: abs(end.x - start.x),
            height: abs(end.y - start.y)
        )
        self.color = color
        self.lineWidth = lineWidth
    }

    init(type: AnnotationType, points: [NSPoint], color: NSColor, lineWidth: CGFloat = 2.0) {
        self.id = UUID()
        self.type = type
        self.points = points
        // Compute bounding rect from points
        let xs = points.map { $0.x }
        let ys = points.map { $0.y }
        let minX = xs.min() ?? 0
        let minY = ys.min() ?? 0
        let maxX = xs.max() ?? 0
        let maxY = ys.max() ?? 0
        self.rect = NSRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
        self.color = color
        self.lineWidth = lineWidth
    }

    init(type: AnnotationType, text: String, position: NSPoint, fontSize: CGFloat, color: NSColor) {
        self.id = UUID()
        self.type = type
        self.text = text
        self.fontSize = fontSize
        self.color = color
        self.lineWidth = 1.0
        let font = NSFont.systemFont(ofSize: fontSize)
        let attrs: [NSAttributedString.Key: Any] = [.font: font]
        let size = (text as NSString).size(withAttributes: attrs)
        self.rect = NSRect(origin: position, size: size)
    }

    init(type: AnnotationType, badgeNumber: Int, center: NSPoint, diameter: CGFloat, color: NSColor) {
        self.id = UUID()
        self.type = type
        self.text = "\(badgeNumber)"
        self.fontSize = diameter * 0.55
        self.color = color
        self.lineWidth = 1.0
        self.rect = NSRect(x: center.x - diameter / 2, y: center.y - diameter / 2, width: diameter, height: diameter)
    }

    func translatedBy(x: CGFloat, y: CGFloat) -> Annotation {
        var copy = self
        copy.rect = rect.offsetBy(dx: x, dy: y)
        copy.startPoint = startPoint.map { NSPoint(x: $0.x + x, y: $0.y + y) }
        copy.endPoint = endPoint.map { NSPoint(x: $0.x + x, y: $0.y + y) }
        copy.points = points?.map { NSPoint(x: $0.x + x, y: $0.y + y) }
        return copy
    }

    func resized(to newRect: NSRect) -> Annotation {
        var copy = self
        let normalizedRect = newRect.standardized
        let oldRect = rect.standardized
        let scaleX = oldRect.width > 0 ? normalizedRect.width / oldRect.width : 1
        let scaleY = oldRect.height > 0 ? normalizedRect.height / oldRect.height : 1
        func mapped(_ point: NSPoint) -> NSPoint {
            NSPoint(
                x: normalizedRect.minX + (point.x - oldRect.minX) * scaleX,
                y: normalizedRect.minY + (point.y - oldRect.minY) * scaleY
            )
        }

        copy.rect = normalizedRect
        copy.startPoint = startPoint.map(mapped)
        copy.endPoint = endPoint.map(mapped)
        copy.points = points?.map(mapped)
        if type == .text, let fontSize {
            copy.fontSize = fontSize * min(scaleX, scaleY)
        }
        return copy
    }

    func duplicated(offset: CGFloat = 12) -> Annotation {
        var copy = translatedBy(x: offset, y: offset)
        copy.id = UUID()
        return copy
    }
}
