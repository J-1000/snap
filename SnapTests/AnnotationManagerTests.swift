import XCTest
@testable import Snap

final class AnnotationManagerTests: XCTestCase {

    private var manager: AnnotationManager!

    override func setUp() {
        super.setUp()
        manager = AnnotationManager()
    }

    // MARK: - Add

    func testAddAppendsAnnotation() {
        let annotation = Annotation(type: .rectangle, rect: NSRect(x: 0, y: 0, width: 50, height: 50), color: .red)
        manager.add(annotation)

        XCTAssertEqual(manager.annotations.count, 1)
        XCTAssertEqual(manager.annotations.first?.id, annotation.id)
    }

    func testAddMultipleAnnotations() {
        for _ in 0..<5 {
            manager.add(Annotation(type: .rectangle, rect: .zero, color: .red))
        }
        XCTAssertEqual(manager.annotations.count, 5)
    }

    func testAddCallsOnChanged() {
        var callCount = 0
        manager.onChanged = { callCount += 1 }

        manager.add(Annotation(type: .rectangle, rect: .zero, color: .red))
        XCTAssertEqual(callCount, 1)

        manager.add(Annotation(type: .ellipse, rect: .zero, color: .blue))
        XCTAssertEqual(callCount, 2)
    }

    // MARK: - Undo

    func testUndoRemovesLastAnnotation() {
        manager.add(Annotation(type: .rectangle, rect: .zero, color: .red))
        manager.add(Annotation(type: .ellipse, rect: .zero, color: .blue))

        manager.undo()
        XCTAssertEqual(manager.annotations.count, 1)
        XCTAssertEqual(manager.annotations.first?.type, .rectangle)
    }

    func testUndoToEmpty() {
        manager.add(Annotation(type: .rectangle, rect: .zero, color: .red))
        manager.undo()
        XCTAssertTrue(manager.annotations.isEmpty)
    }

    func testUndoOnEmptyDoesNothing() {
        manager.undo()
        XCTAssertTrue(manager.annotations.isEmpty)
    }

    func testUndoCallsOnChanged() {
        manager.add(Annotation(type: .rectangle, rect: .zero, color: .red))

        var called = false
        manager.onChanged = { called = true }
        manager.undo()
        XCTAssertTrue(called)
    }

    func testUndoOnEmptyDoesNotCallOnChanged() {
        var called = false
        manager.onChanged = { called = true }
        manager.undo()
        XCTAssertFalse(called)
    }

    // MARK: - Redo

    func testRedoRestoresAnnotation() {
        let annotation = Annotation(type: .rectangle, rect: .zero, color: .red)
        manager.add(annotation)
        manager.undo()
        manager.redo()

        XCTAssertEqual(manager.annotations.count, 1)
        XCTAssertEqual(manager.annotations.first?.id, annotation.id)
    }

    func testRedoOnEmptyDoesNothing() {
        manager.redo()
        XCTAssertTrue(manager.annotations.isEmpty)
    }

    func testRedoCallsOnChanged() {
        manager.add(Annotation(type: .rectangle, rect: .zero, color: .red))
        manager.undo()

        var called = false
        manager.onChanged = { called = true }
        manager.redo()
        XCTAssertTrue(called)
    }

    func testRedoOnEmptyDoesNotCallOnChanged() {
        var called = false
        manager.onChanged = { called = true }
        manager.redo()
        XCTAssertFalse(called)
    }

    // MARK: - Undo/Redo interaction

    func testAddClearsRedoStack() {
        manager.add(Annotation(type: .rectangle, rect: .zero, color: .red))
        manager.undo()
        XCTAssertTrue(manager.canRedo)

        manager.add(Annotation(type: .ellipse, rect: .zero, color: .blue))
        XCTAssertFalse(manager.canRedo)
    }

    func testMultipleUndoRedo() {
        let a1 = Annotation(type: .rectangle, rect: .zero, color: .red)
        let a2 = Annotation(type: .ellipse, rect: .zero, color: .blue)
        let a3 = Annotation(type: .line, start: .zero, end: NSPoint(x: 10, y: 10), color: .green)

        manager.add(a1)
        manager.add(a2)
        manager.add(a3)
        XCTAssertEqual(manager.annotations.count, 3)

        manager.undo()
        XCTAssertEqual(manager.annotations.count, 2)

        manager.undo()
        XCTAssertEqual(manager.annotations.count, 1)

        manager.redo()
        XCTAssertEqual(manager.annotations.count, 2)

        manager.redo()
        XCTAssertEqual(manager.annotations.count, 3)
    }

    // MARK: - canUndo / canRedo

    func testCanUndoInitiallyFalse() {
        XCTAssertFalse(manager.canUndo)
    }

    func testCanRedoInitiallyFalse() {
        XCTAssertFalse(manager.canRedo)
    }

    func testCanUndoAfterAdd() {
        manager.add(Annotation(type: .rectangle, rect: .zero, color: .red))
        XCTAssertTrue(manager.canUndo)
    }

    func testCanRedoAfterUndo() {
        manager.add(Annotation(type: .rectangle, rect: .zero, color: .red))
        manager.undo()
        XCTAssertTrue(manager.canRedo)
    }

    func testCanUndoFalseAfterFullUndo() {
        manager.add(Annotation(type: .rectangle, rect: .zero, color: .red))
        manager.undo()
        XCTAssertFalse(manager.canUndo)
    }

    func testCanRedoFalseAfterFullRedo() {
        manager.add(Annotation(type: .rectangle, rect: .zero, color: .red))
        manager.undo()
        manager.redo()
        XCTAssertFalse(manager.canRedo)
    }

    // MARK: - Rendering

    func testRenderDoesNotCrashWithNoAnnotations() {
        let context = createTestContext(width: 100, height: 100)
        manager.render(in: context, size: NSSize(width: 100, height: 100))
        // No crash = pass
    }

    func testRenderWithRectangleAnnotation() {
        manager.add(Annotation(type: .rectangle, rect: NSRect(x: 10, y: 10, width: 50, height: 30), color: .red))
        let context = createTestContext(width: 100, height: 100)
        manager.render(in: context, size: NSSize(width: 100, height: 100))

        // Verify something was drawn (non-blank image)
        guard let image = context.makeImage() else {
            XCTFail("Failed to create image from context")
            return
        }
        XCTAssertFalse(isBlankImage(image))
    }

    func testRenderWithEllipseAnnotation() {
        manager.add(Annotation(type: .ellipse, rect: NSRect(x: 10, y: 10, width: 50, height: 30), color: .blue))
        let context = createTestContext(width: 100, height: 100)
        manager.render(in: context, size: NSSize(width: 100, height: 100))

        guard let image = context.makeImage() else {
            XCTFail("Failed to create image from context")
            return
        }
        XCTAssertFalse(isBlankImage(image))
    }

    func testRenderWithLineAnnotation() {
        manager.add(Annotation(type: .line, start: NSPoint(x: 0, y: 0), end: NSPoint(x: 80, y: 80), color: .green))
        let context = createTestContext(width: 100, height: 100)
        manager.render(in: context, size: NSSize(width: 100, height: 100))

        guard let image = context.makeImage() else {
            XCTFail("Failed to create image from context")
            return
        }
        XCTAssertFalse(isBlankImage(image))
    }

    func testRenderWithArrowAnnotation() {
        manager.add(Annotation(type: .arrow, start: NSPoint(x: 10, y: 10), end: NSPoint(x: 80, y: 80), color: .red))
        let context = createTestContext(width: 100, height: 100)
        manager.render(in: context, size: NSSize(width: 100, height: 100))

        guard let image = context.makeImage() else {
            XCTFail("Failed to create image from context")
            return
        }
        XCTAssertFalse(isBlankImage(image))
    }

    func testRenderWithFreehandAnnotation() {
        let points = [NSPoint(x: 10, y: 10), NSPoint(x: 30, y: 50), NSPoint(x: 60, y: 20)]
        manager.add(Annotation(type: .freehand, points: points, color: .yellow))
        let context = createTestContext(width: 100, height: 100)
        manager.render(in: context, size: NSSize(width: 100, height: 100))

        guard let image = context.makeImage() else {
            XCTFail("Failed to create image from context")
            return
        }
        XCTAssertFalse(isBlankImage(image))
    }

    func testRenderFreehandWithSinglePointDoesNotCrash() {
        manager.add(Annotation(type: .freehand, points: [NSPoint(x: 5, y: 5)], color: .red))
        let context = createTestContext(width: 100, height: 100)
        manager.render(in: context, size: NSSize(width: 100, height: 100))
    }

    func testRenderFreehandWithEmptyPointsDoesNotCrash() {
        manager.add(Annotation(type: .freehand, points: [], color: .red))
        let context = createTestContext(width: 100, height: 100)
        manager.render(in: context, size: NSSize(width: 100, height: 100))
    }

    func testRenderWithTextAnnotation() {
        manager.add(Annotation(type: .text, text: "Hello", position: NSPoint(x: 10, y: 10), fontSize: 16, color: .black))
        let context = createTestContext(width: 200, height: 200)
        // Push NSGraphicsContext so text rendering can work
        let nsContext = NSGraphicsContext(cgContext: context, flipped: true)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = nsContext
        manager.render(in: context, size: NSSize(width: 200, height: 200))
        NSGraphicsContext.restoreGraphicsState()

        guard let image = context.makeImage() else {
            XCTFail("Failed to create image from context")
            return
        }
        XCTAssertFalse(isBlankImage(image))
    }

    func testRenderTextWithNilTextDoesNotCrash() {
        // Text annotation created via rect init (text field will be nil)
        manager.add(Annotation(type: .text, rect: NSRect(x: 0, y: 0, width: 50, height: 20), color: .red))
        let context = createTestContext(width: 100, height: 100)
        manager.render(in: context, size: NSSize(width: 100, height: 100))
    }

    // MARK: - Compositing

    func testCompositeReturnsImage() {
        let baseImage = createTestImage(width: 200, height: 200)
        manager.add(Annotation(type: .rectangle, rect: NSRect(x: 10, y: 10, width: 50, height: 50), color: .red, lineWidth: 3))

        let result = manager.composite(onto: baseImage)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.width, 200)
        XCTAssertEqual(result?.height, 200)
    }

    func testCompositeWithNoAnnotationsPreservesImage() {
        let baseImage = createTestImage(width: 100, height: 100)
        let result = manager.composite(onto: baseImage)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.width, 100)
        XCTAssertEqual(result?.height, 100)
    }

    func testCompositeModifiesImage() {
        let baseImage = createTestImage(width: 100, height: 100, fillColor: .white)
        manager.add(Annotation(type: .rectangle, rect: NSRect(x: 10, y: 10, width: 80, height: 80), color: .red, lineWidth: 4))

        guard let result = manager.composite(onto: baseImage) else {
            XCTFail("Composite returned nil")
            return
        }

        // The composited image should differ from a blank white image
        XCTAssertFalse(imagesAreIdentical(baseImage, result))
    }

    // MARK: - Helpers

    private func createTestContext(width: Int, height: Int) -> CGContext {
        CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
    }

    private func createTestImage(width: Int, height: Int, fillColor: NSColor = .clear) -> CGImage {
        let context = createTestContext(width: width, height: height)
        context.setFillColor(fillColor.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()!
    }

    private func isBlankImage(_ image: CGImage) -> Bool {
        guard let data = image.dataProvider?.data,
              let ptr = CFDataGetBytePtr(data) else { return true }
        let length = CFDataGetLength(data)
        for i in 0..<length {
            if ptr[i] != 0 { return false }
        }
        return true
    }

    private func imagesAreIdentical(_ a: CGImage, _ b: CGImage) -> Bool {
        guard a.width == b.width, a.height == b.height,
              let dataA = a.dataProvider?.data,
              let dataB = b.dataProvider?.data else { return false }
        let ptrA = CFDataGetBytePtr(dataA)
        let ptrB = CFDataGetBytePtr(dataB)
        let length = CFDataGetLength(dataA)
        guard length == CFDataGetLength(dataB) else { return false }
        return memcmp(ptrA, ptrB, length) == 0
    }
}
