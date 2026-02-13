import AppKit
import Foundation

enum AnnotationType {
    case rectangle
    case ellipse
    case line
    case arrow
}

struct Annotation {
    let id: UUID
    let type: AnnotationType
    var rect: NSRect
    var startPoint: NSPoint?
    var endPoint: NSPoint?
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
}
