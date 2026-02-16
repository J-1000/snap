import XCTest
@testable import Snap

final class AnnotationTests: XCTestCase {

    // MARK: - Rect-based initializer

    func testRectInitSetsTypeAndRect() {
        let rect = NSRect(x: 10, y: 20, width: 100, height: 50)
        let annotation = Annotation(type: .rectangle, rect: rect, color: .red)

        XCTAssertEqual(annotation.type, .rectangle)
        XCTAssertEqual(annotation.rect, rect)
        XCTAssertEqual(annotation.color, .red)
    }

    func testRectInitDefaultLineWidth() {
        let annotation = Annotation(type: .ellipse, rect: .zero, color: .blue)
        XCTAssertEqual(annotation.lineWidth, 2.0)
    }

    func testRectInitCustomLineWidth() {
        let annotation = Annotation(type: .rectangle, rect: .zero, color: .blue, lineWidth: 5.0)
        XCTAssertEqual(annotation.lineWidth, 5.0)
    }

    func testRectInitHasUniqueID() {
        let a = Annotation(type: .rectangle, rect: .zero, color: .red)
        let b = Annotation(type: .rectangle, rect: .zero, color: .red)
        XCTAssertNotEqual(a.id, b.id)
    }

    func testRectInitPointsAreNil() {
        let annotation = Annotation(type: .rectangle, rect: .zero, color: .red)
        XCTAssertNil(annotation.startPoint)
        XCTAssertNil(annotation.endPoint)
        XCTAssertNil(annotation.points)
    }

    // MARK: - Point-based initializer

    func testPointInitSetsStartAndEnd() {
        let start = NSPoint(x: 10, y: 20)
        let end = NSPoint(x: 110, y: 70)
        let annotation = Annotation(type: .line, start: start, end: end, color: .green)

        XCTAssertEqual(annotation.startPoint, start)
        XCTAssertEqual(annotation.endPoint, end)
        XCTAssertEqual(annotation.type, .line)
    }

    func testPointInitComputesBoundingRect() {
        let start = NSPoint(x: 50, y: 100)
        let end = NSPoint(x: 150, y: 30)
        let annotation = Annotation(type: .arrow, start: start, end: end, color: .green)

        XCTAssertEqual(annotation.rect.origin.x, 50, accuracy: 0.001)
        XCTAssertEqual(annotation.rect.origin.y, 30, accuracy: 0.001)
        XCTAssertEqual(annotation.rect.size.width, 100, accuracy: 0.001)
        XCTAssertEqual(annotation.rect.size.height, 70, accuracy: 0.001)
    }

    func testPointInitWithReversedCoordinates() {
        let start = NSPoint(x: 200, y: 300)
        let end = NSPoint(x: 50, y: 100)
        let annotation = Annotation(type: .line, start: start, end: end, color: .red)

        XCTAssertEqual(annotation.rect.origin.x, 50, accuracy: 0.001)
        XCTAssertEqual(annotation.rect.origin.y, 100, accuracy: 0.001)
        XCTAssertEqual(annotation.rect.size.width, 150, accuracy: 0.001)
        XCTAssertEqual(annotation.rect.size.height, 200, accuracy: 0.001)
    }

    // MARK: - Freehand (points array) initializer

    func testFreehandInitSetsPoints() {
        let points = [NSPoint(x: 0, y: 0), NSPoint(x: 10, y: 20), NSPoint(x: 30, y: 5)]
        let annotation = Annotation(type: .freehand, points: points, color: .yellow)

        XCTAssertEqual(annotation.type, .freehand)
        XCTAssertEqual(annotation.points?.count, 3)
    }

    func testFreehandInitComputesBoundingRect() {
        let points = [NSPoint(x: 5, y: 10), NSPoint(x: 50, y: 80), NSPoint(x: 25, y: 3)]
        let annotation = Annotation(type: .freehand, points: points, color: .yellow)

        XCTAssertEqual(annotation.rect.origin.x, 5, accuracy: 0.001)
        XCTAssertEqual(annotation.rect.origin.y, 3, accuracy: 0.001)
        XCTAssertEqual(annotation.rect.size.width, 45, accuracy: 0.001)
        XCTAssertEqual(annotation.rect.size.height, 77, accuracy: 0.001)
    }

    func testFreehandInitSinglePoint() {
        let points = [NSPoint(x: 42, y: 17)]
        let annotation = Annotation(type: .freehand, points: points, color: .red)

        XCTAssertEqual(annotation.rect.origin.x, 42, accuracy: 0.001)
        XCTAssertEqual(annotation.rect.origin.y, 17, accuracy: 0.001)
        XCTAssertEqual(annotation.rect.size.width, 0, accuracy: 0.001)
        XCTAssertEqual(annotation.rect.size.height, 0, accuracy: 0.001)
    }

    func testFreehandInitEmptyPoints() {
        let annotation = Annotation(type: .freehand, points: [], color: .red)

        XCTAssertEqual(annotation.rect.origin.x, 0, accuracy: 0.001)
        XCTAssertEqual(annotation.rect.origin.y, 0, accuracy: 0.001)
        XCTAssertEqual(annotation.rect.size.width, 0, accuracy: 0.001)
        XCTAssertEqual(annotation.rect.size.height, 0, accuracy: 0.001)
    }

    // MARK: - Text initializer

    func testTextInitSetsTextAndFontSize() {
        let annotation = Annotation(type: .text, text: "Hello", position: NSPoint(x: 10, y: 20), fontSize: 18, color: .black)

        XCTAssertEqual(annotation.type, .text)
        XCTAssertEqual(annotation.text, "Hello")
        XCTAssertEqual(annotation.fontSize, 18)
        XCTAssertEqual(annotation.color, .black)
    }

    func testTextInitComputesBoundingRect() {
        let annotation = Annotation(type: .text, text: "Test", position: NSPoint(x: 30, y: 40), fontSize: 16, color: .red)

        XCTAssertEqual(annotation.rect.origin.x, 30, accuracy: 0.001)
        XCTAssertEqual(annotation.rect.origin.y, 40, accuracy: 0.001)
        XCTAssertGreaterThan(annotation.rect.size.width, 0)
        XCTAssertGreaterThan(annotation.rect.size.height, 0)
    }

    func testTextInitHasUniqueID() {
        let a = Annotation(type: .text, text: "A", position: .zero, fontSize: 16, color: .red)
        let b = Annotation(type: .text, text: "A", position: .zero, fontSize: 16, color: .red)
        XCTAssertNotEqual(a.id, b.id)
    }

    func testTextInitPointFieldsAreNil() {
        let annotation = Annotation(type: .text, text: "Hi", position: .zero, fontSize: 16, color: .red)
        XCTAssertNil(annotation.startPoint)
        XCTAssertNil(annotation.endPoint)
        XCTAssertNil(annotation.points)
    }

    func testRectInitTextFieldsAreNil() {
        let annotation = Annotation(type: .rectangle, rect: .zero, color: .red)
        XCTAssertNil(annotation.text)
        XCTAssertNil(annotation.fontSize)
    }

    // MARK: - AnnotationType cases

    func testAllAnnotationTypesExist() {
        let types: [AnnotationType] = [.rectangle, .ellipse, .line, .arrow, .freehand, .text, .blur]
        XCTAssertEqual(types.count, 7)
    }

    // MARK: - Blur initializer

    func testBlurInitSetsTypeAndRect() {
        let rect = NSRect(x: 20, y: 30, width: 80, height: 60)
        let annotation = Annotation(type: .blur, rect: rect, color: .clear)

        XCTAssertEqual(annotation.type, .blur)
        XCTAssertEqual(annotation.rect, rect)
    }

    func testBlurInitHasUniqueID() {
        let a = Annotation(type: .blur, rect: .zero, color: .clear)
        let b = Annotation(type: .blur, rect: .zero, color: .clear)
        XCTAssertNotEqual(a.id, b.id)
    }

    func testBlurInitPointFieldsAreNil() {
        let annotation = Annotation(type: .blur, rect: .zero, color: .clear)
        XCTAssertNil(annotation.startPoint)
        XCTAssertNil(annotation.endPoint)
        XCTAssertNil(annotation.points)
        XCTAssertNil(annotation.text)
    }
}
