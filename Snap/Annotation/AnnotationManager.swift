import AppKit

final class AnnotationManager {
    private(set) var annotations: [Annotation] = [] {
        didSet { compositeCache = nil }
    }
    private var undoStack: [[Annotation]] = []
    private var redoStack: [[Annotation]] = []
    private var compositeCache: CGImage?
    private var transactionSnapshot: [Annotation]?

    /// Shared Core Image context — expensive to construct, so reuse one across
    /// blur renders and live previews instead of allocating per frame.
    static let ciContext = CIContext()

    var onChanged: (() -> Void)?

    func add(_ annotation: Annotation) {
        undoStack.append(annotations)
        redoStack.removeAll()
        annotations.append(annotation)
        onChanged?()
    }

    /// Remove the most recently added annotation (delete/backspace in the editor).
    func removeLast() {
        guard !annotations.isEmpty else { return }
        undoStack.append(annotations)
        redoStack.removeAll()
        annotations.removeLast()
        onChanged?()
    }

    func annotation(withID id: UUID) -> Annotation? {
        annotations.first { $0.id == id }
    }

    func annotation(at point: NSPoint, tolerance: CGFloat = 6) -> Annotation? {
        annotations.reversed().first {
            $0.rect.insetBy(dx: -tolerance, dy: -tolerance).contains(point)
        }
    }

    func beginTransaction() {
        guard transactionSnapshot == nil else { return }
        transactionSnapshot = annotations
    }

    func commitTransaction() {
        guard let snapshot = transactionSnapshot else { return }
        transactionSnapshot = nil
        undoStack.append(snapshot)
        redoStack.removeAll()
    }

    func cancelTransaction() {
        guard let snapshot = transactionSnapshot else { return }
        transactionSnapshot = nil
        annotations = snapshot
        onChanged?()
    }

    @discardableResult
    func replace(_ annotation: Annotation) -> Bool {
        guard let index = annotations.firstIndex(where: { $0.id == annotation.id }) else { return false }
        recordUndoForMutation()
        annotations[index] = annotation
        onChanged?()
        return true
    }

    @discardableResult
    func remove(id: UUID) -> Bool {
        guard let index = annotations.firstIndex(where: { $0.id == id }) else { return false }
        recordUndoForMutation()
        annotations.remove(at: index)
        onChanged?()
        return true
    }

    @discardableResult
    func recolor(id: UUID, color: NSColor) -> Bool {
        guard var annotation = annotation(withID: id) else { return false }
        annotation.color = color
        return replace(annotation)
    }

    @discardableResult
    func duplicate(id: UUID, offset: CGFloat = 12) -> UUID? {
        guard let annotation = annotation(withID: id) else { return nil }
        let copy = annotation.duplicated(offset: offset)
        recordUndoForMutation()
        annotations.append(copy)
        onChanged?()
        return copy.id
    }

    @discardableResult
    func bringForward(id: UUID) -> Bool {
        guard let index = annotations.firstIndex(where: { $0.id == id }),
              index < annotations.count - 1 else { return false }
        recordUndoForMutation()
        annotations.swapAt(index, index + 1)
        onChanged?()
        return true
    }

    @discardableResult
    func sendBackward(id: UUID) -> Bool {
        guard let index = annotations.firstIndex(where: { $0.id == id }), index > 0 else { return false }
        recordUndoForMutation()
        annotations.swapAt(index, index - 1)
        onChanged?()
        return true
    }

    private func recordUndoForMutation() {
        guard transactionSnapshot == nil else { return }
        undoStack.append(annotations)
        redoStack.removeAll()
    }

    func undo() {
        transactionSnapshot = nil
        guard let previous = undoStack.popLast() else { return }
        redoStack.append(annotations)
        annotations = previous
        onChanged?()
    }

    func redo() {
        transactionSnapshot = nil
        guard let next = redoStack.popLast() else { return }
        undoStack.append(annotations)
        annotations = next
        onChanged?()
    }

    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }

    func render(in context: CGContext, size: NSSize, sourceImage: CGImage? = nil) {
        for annotation in annotations {
            renderAnnotation(annotation, in: context, size: size, sourceImage: sourceImage)
        }
    }

    /// Render a single annotation — used for the in-progress drag preview so it
    /// goes through the same code path as committed annotations.
    func render(_ annotation: Annotation, in context: CGContext, size: NSSize, sourceImage: CGImage? = nil) {
        renderAnnotation(annotation, in: context, size: size, sourceImage: sourceImage)
    }

    private func renderAnnotation(_ annotation: Annotation, in context: CGContext, size: NSSize, sourceImage: CGImage? = nil) {
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
            guard let text = annotation.text, let fontSize = annotation.fontSize else { return }
            let font = NSFont.systemFont(ofSize: fontSize)
            let attrs: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: annotation.color,
            ]
            let attrString = NSAttributedString(string: text, attributes: attrs)
            let nsContext = NSGraphicsContext(cgContext: context, flipped: true)
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = nsContext
            attrString.draw(at: annotation.rect.origin)
            NSGraphicsContext.restoreGraphicsState()
        case .blur:
            renderBlur(annotation, in: context, sourceImage: sourceImage)
        case .redact:
            // Redactions must remain fully opaque in every output format. Do
            // not derive this color from the annotation palette or source.
            context.setFillColor(NSColor.black.cgColor)
            context.fill(annotation.rect)
        case .stepBadge:
            guard let text = annotation.text else { return }
            context.setFillColor(annotation.color.cgColor)
            context.fillEllipse(in: annotation.rect)
            let fontSize = annotation.fontSize ?? annotation.rect.height * 0.55
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.boldSystemFont(ofSize: fontSize),
                .foregroundColor: NSColor.white,
            ]
            let attrString = NSAttributedString(string: text, attributes: attrs)
            let textSize = attrString.size()
            let origin = NSPoint(
                x: annotation.rect.midX - textSize.width / 2,
                y: annotation.rect.midY - textSize.height / 2
            )
            let nsContext = NSGraphicsContext(cgContext: context, flipped: true)
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = nsContext
            attrString.draw(at: origin)
            NSGraphicsContext.restoreGraphicsState()
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

    private func renderBlur(_ annotation: Annotation, in context: CGContext, sourceImage: CGImage?) {
        guard let sourceImage = sourceImage else { return }
        let rect = annotation.rect
        guard rect.width > 0, rect.height > 0 else { return }

        // Convert from top-left (annotation) to bottom-left (CGImage) coordinates
        let imageHeight = CGFloat(sourceImage.height)
        let cropRect = CGRect(
            x: rect.origin.x,
            y: imageHeight - rect.maxY,
            width: rect.width,
            height: rect.height
        ).integral.intersection(CGRect(x: 0, y: 0, width: CGFloat(sourceImage.width), height: imageHeight))

        guard !cropRect.isEmpty,
              let croppedImage = sourceImage.cropping(to: cropRect) else { return }

        let ciImage = CIImage(cgImage: croppedImage)
        let pixelScale = max(rect.width, rect.height) / 10
        guard let filter = CIFilter(name: "CIPixellate") else { return }
        filter.setValue(ciImage, forKey: kCIInputImageKey)
        filter.setValue(max(pixelScale, 2.0), forKey: kCIInputScaleKey)

        guard let outputImage = filter.outputImage,
              let pixelatedCGImage = AnnotationManager.ciContext.createCGImage(outputImage, from: ciImage.extent) else { return }

        // Context is already flipped to top-left origin; draw pixelated region back
        context.draw(pixelatedCGImage, in: rect)
    }

    /// Composites annotations onto a CGImage, returning a new image.
    func composite(onto image: CGImage) -> CGImage? {
        // Nothing to draw — return the original instead of doing a full-size
        // off-screen copy. Cache the result so repeated output actions (e.g.
        // Copy then Save) don't re-composite.
        guard !annotations.isEmpty else { return image }
        if let cached = compositeCache { return cached }

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

        render(in: context, size: NSSize(width: width, height: height), sourceImage: image)

        let result = context.makeImage()
        compositeCache = result
        return result
    }
}
