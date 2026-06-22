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
        case .stepBadge: return "Step Badge"
        }
    }
}

struct Annotation {
    let id: UUID
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
}
