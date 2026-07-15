import XCTest
@testable import Snap

final class SelectionGeometryTests: XCTestCase {
    private let geo = SelectionGeometry(bounds: NSRect(x: 0, y: 0, width: 1000, height: 800))

    func testNormalizedRectIsDirectionIndependent() {
        let a = geo.normalizedRect(from: NSPoint(x: 10, y: 20), to: NSPoint(x: 110, y: 220))
        let b = geo.normalizedRect(from: NSPoint(x: 110, y: 220), to: NSPoint(x: 10, y: 20))
        XCTAssertEqual(a, b)
        XCTAssertEqual(a, NSRect(x: 10, y: 20, width: 100, height: 200))
    }

    func testConstrainedSquareIsSquareInAllDirections() {
        let origin = NSPoint(x: 100, y: 100)
        let targets = [
            NSPoint(x: 180, y: 140), NSPoint(x: 20, y: 140),
            NSPoint(x: 180, y: 40), NSPoint(x: 20, y: 40),
        ]
        for target in targets {
            let rect = geo.constrainedSquare(from: origin, to: target)
            XCTAssertEqual(rect.width, rect.height, accuracy: 0.0001)
            let expectedSide = max(abs(target.x - origin.x), abs(target.y - origin.y))
            XCTAssertEqual(rect.width, expectedSide, accuracy: 0.0001)
        }
    }

    func testDrawingRectClipsPointerOutsideDisplay() {
        let rect = geo.drawingRect(
            from: NSPoint(x: 100, y: 100),
            to: NSPoint(x: 1200, y: -50),
            constrained: false
        )

        XCTAssertEqual(rect, NSRect(x: 100, y: 0, width: 900, height: 100))
    }

    func testConstrainedDrawingStaysSquareInsideDisplay() {
        let rect = geo.drawingRect(
            from: NSPoint(x: 900, y: 700),
            to: NSPoint(x: 1200, y: 1000),
            constrained: true
        )

        XCTAssertEqual(rect, NSRect(x: 900, y: 700, width: 100, height: 100))
        XCTAssertTrue(geo.bounds.contains(rect))
    }

    func testClampedCapsSizeAndKeepsOnScreen() {
        let huge = geo.clamped(NSRect(x: -50, y: -50, width: 2000, height: 2000))
        XCTAssertEqual(huge, NSRect(x: 0, y: 0, width: 1000, height: 800))

        let off = geo.clamped(NSRect(x: 950, y: 750, width: 100, height: 100))
        XCTAssertEqual(off.maxX, 1000, accuracy: 0.001)
        XCTAssertEqual(off.maxY, 800, accuracy: 0.001)
    }

    func testHandleRectsAreCenteredOnCorners() {
        let sel = NSRect(x: 100, y: 100, width: 200, height: 100)
        let rects = geo.handleRects(for: sel)
        XCTAssertEqual(rects.count, 8)
        XCTAssertEqual(rects[.topLeft]!.midX, sel.minX, accuracy: 0.001)
        XCTAssertEqual(rects[.topLeft]!.midY, sel.maxY, accuracy: 0.001)
        XCTAssertEqual(rects[.bottomRight]!.midX, sel.maxX, accuracy: 0.001)
        XCTAssertEqual(rects[.bottomRight]!.midY, sel.minY, accuracy: 0.001)
    }

    func testResizeHandleHitTesting() {
        let sel = NSRect(x: 100, y: 100, width: 200, height: 100)
        XCTAssertEqual(geo.resizeHandle(at: NSPoint(x: sel.minX, y: sel.maxY), in: sel), .topLeft)
        XCTAssertEqual(geo.resizeHandle(at: NSPoint(x: sel.maxX, y: sel.minY), in: sel), .bottomRight)
        XCTAssertNil(geo.resizeHandle(at: NSPoint(x: sel.midX, y: sel.midY), in: sel))
    }

    func testAnchorIsOppositeCorner() {
        let sel = NSRect(x: 100, y: 100, width: 200, height: 100)
        XCTAssertEqual(geo.anchorPoint(for: .topLeft, in: sel), NSPoint(x: sel.maxX, y: sel.minY))
        XCTAssertEqual(geo.anchorPoint(for: .bottomRight, in: sel), NSPoint(x: sel.minX, y: sel.maxY))
    }

    func testResizingPastAnchorIsContinuous() {
        // Dragging a corner handle through its anchor must invert smoothly with
        // no jump (regression guard for the "teleport" report that was refuted).
        let sel = NSRect(x: 100, y: 100, width: 200, height: 100)
        let anchor = geo.anchorPoint(for: .topLeft, in: sel) // bottom-right corner
        let before = geo.resizedRect(handle: .topLeft, original: sel, anchor: anchor, current: NSPoint(x: anchor.x + 1, y: anchor.y + 1))
        let at = geo.resizedRect(handle: .topLeft, original: sel, anchor: anchor, current: anchor)
        let after = geo.resizedRect(handle: .topLeft, original: sel, anchor: anchor, current: NSPoint(x: anchor.x - 1, y: anchor.y - 1))
        XCTAssertEqual(before.width, 1, accuracy: 0.001)
        XCTAssertEqual(at.width, 0, accuracy: 0.001)
        XCTAssertEqual(after.width, 1, accuracy: 0.001)
    }
}
