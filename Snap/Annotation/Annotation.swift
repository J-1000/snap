import AppKit
import Foundation

enum AnnotationType {
    case rectangle
}

struct Annotation {
    let id: UUID
    let type: AnnotationType
    var rect: NSRect
    var color: NSColor
    var lineWidth: CGFloat

    init(type: AnnotationType, rect: NSRect, color: NSColor, lineWidth: CGFloat = 2.0) {
        self.id = UUID()
        self.type = type
        self.rect = rect
        self.color = color
        self.lineWidth = lineWidth
    }
}
