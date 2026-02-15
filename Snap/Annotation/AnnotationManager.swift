import AppKit

final class AnnotationManager {
    private(set) var annotations: [Annotation] = []
    private var undoStack: [[Annotation]] = []
    private var redoStack: [[Annotation]] = []

    var onChanged: (() -> Void)?

    func add(_ annotation: Annotation) {
        undoStack.append(annotations)
        redoStack.removeAll()
        annotations.append(annotation)
        onChanged?()
    }

    func undo() {
        guard let previous = undoStack.popLast() else { return }
        redoStack.append(annotations)
        annotations = previous
        onChanged?()
    }

    func redo() {
        guard let next = redoStack.popLast() else { return }
        undoStack.append(annotations)
        annotations = next
        onChanged?()
    }

    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }

    func render(in context: CGContext, size: NSSize) {
        for annotation in annotations {
            renderAnnotation(annotation, in: context, size: size)
        }
    }

    private func renderAnnotation(_ annotation: Annotation, in context: CGContext, size: NSSize) {
        switch annotation.type {
        case .rectangle:
            context.setStrokeColor(annotation.color.cgColor)
            context.setLineWidth(annotation.lineWidth)
            context.stroke(annotation.rect)
        case .ellipse:
            context.setStrokeColor(annotation.color.cgColor)
            context.setLineWidth(annotation.lineWidth)
            context.strokeEllipse(in: annotation.rect)
        case .line:
            guard let start = annotation.startPoint, let end = annotation.endPoint else { return }
            context.setStrokeColor(annotation.color.cgColor)
            context.setLineWidth(annotation.lineWidth)
            context.beginPath()
            context.move(to: start)
            context.addLine(to: end)
            context.strokePath()
        case .arrow:
            guard let start = annotation.startPoint, let end = annotation.endPoint else { return }
            context.setStrokeColor(annotation.color.cgColor)
            context.setFillColor(annotation.color.cgColor)
            context.setLineWidth(annotation.lineWidth)
            context.beginPath()
            context.move(to: start)
            context.addLine(to: end)
            context.strokePath()
            drawArrowhead(in: context, from: start, to: end, size: max(10, annotation.lineWidth * 5))
        case .freehand:
            guard let points = annotation.points, points.count >= 2 else { return }
            context.setStrokeColor(annotation.color.cgColor)
            context.setLineWidth(annotation.lineWidth)
            context.setLineCap(.round)
            context.setLineJoin(.round)
            context.beginPath()
            context.move(to: points[0])
            for i in 1..<points.count {
                context.addLine(to: points[i])
            }
            context.strokePath()
        case .text:
            break // Rendering implemented in next step
        }
    }

    private func drawArrowhead(in context: CGContext, from start: CGPoint, to end: CGPoint, size: CGFloat) {
        let angle = atan2(end.y - start.y, end.x - start.x)
        let spreadAngle: CGFloat = .pi / 6  // 30 degrees

        let left = CGPoint(
            x: end.x - size * cos(angle - spreadAngle),
            y: end.y - size * sin(angle - spreadAngle)
        )
        let right = CGPoint(
            x: end.x - size * cos(angle + spreadAngle),
            y: end.y - size * sin(angle + spreadAngle)
        )

        context.beginPath()
        context.move(to: end)
        context.addLine(to: left)
        context.addLine(to: right)
        context.closePath()
        context.fillPath()
    }

    /// Composites annotations onto a CGImage, returning a new image.
    func composite(onto image: CGImage) -> CGImage? {
        let width = image.width
        let height = image.height
        let colorSpace = image.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB)!
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        let fullRect = CGRect(x: 0, y: 0, width: width, height: height)
        context.draw(image, in: fullRect)

        // Annotations are stored in view coordinates (origin top-left).
        // CGContext for the image has origin bottom-left. Flip it.
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: 1, y: -1)

        render(in: context, size: NSSize(width: width, height: height))

        return context.makeImage()
    }
}
