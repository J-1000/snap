import XCTest
@testable import Snap

final class AnnotationRenderingTests: XCTestCase {
    private func whiteImage(width: Int, height: Int) -> CGImage {
        let cs = CGColorSpace(name: CGColorSpace.sRGB)!
        let ctx = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
        return ctx.makeImage()!
    }

    private func stripedImage(width: Int, height: Int) -> CGImage {
        let cs = CGColorSpace(name: CGColorSpace.sRGB)!
        let ctx = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        for y in 0..<height {
            let fraction = CGFloat(y) / CGFloat(max(height - 1, 1))
            ctx.setFillColor(CGColor(red: fraction, green: 0.25, blue: 1 - fraction, alpha: 1))
            ctx.fill(CGRect(x: 0, y: y, width: width, height: 1))
        }
        return ctx.makeImage()!
    }

    /// (r,g,b,a) 0–255 at image pixel (x, y) in top-left-origin coordinates.
    private func pixel(_ image: CGImage, x: Int, y: Int) -> (UInt8, UInt8, UInt8, UInt8) {
        let width = image.width
        let height = image.height
        var data = [UInt8](repeating: 0, count: width * height * 4)
        let cs = CGColorSpace(name: CGColorSpace.sRGB)!
        let ctx = CGContext(
            data: &data, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
            space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        let flippedY = height - 1 - y // context is bottom-left origin
        let offset = (flippedY * width + x) * 4
        return (data[offset], data[offset + 1], data[offset + 2], data[offset + 3])
    }

    func testStepBadgeFillsColorAndLeavesBackground() {
        let source = whiteImage(width: 100, height: 100)
        let manager = AnnotationManager()
        manager.add(Annotation(type: .stepBadge, badgeNumber: 1, center: NSPoint(x: 50, y: 50), diameter: 40, color: .red))
        let output = manager.composite(onto: source)!

        // Inside the badge ring (left of the centered digit) is the badge color.
        let fill = pixel(output, x: 35, y: 50)
        XCTAssertGreaterThan(fill.0, 180, "red channel")
        XCTAssertLessThan(fill.1, 90, "green channel")
        XCTAssertLessThan(fill.2, 90, "blue channel")

        // A corner well outside the badge stays white (compositing didn't smear).
        let corner = pixel(output, x: 5, y: 5)
        XCTAssertGreaterThan(corner.0, 230)
        XCTAssertGreaterThan(corner.1, 230)
        XCTAssertGreaterThan(corner.2, 230)
    }

    func testEmptyManagerReturnsSource() {
        let source = whiteImage(width: 10, height: 10)
        let output = AnnotationManager().composite(onto: source)
        XCTAssertEqual(output?.width, 10)
        XCTAssertEqual(output?.height, 10)
    }

    func testSolidRedactionExportsOpaqueBlackPixels() {
        let source = whiteImage(width: 40, height: 40)
        let manager = AnnotationManager()
        manager.add(
            Annotation(
                type: .redact,
                rect: NSRect(x: 10, y: 12, width: 20, height: 16),
                color: .systemPink
            )
        )

        let output = manager.composite(onto: source)!
        let covered = pixel(output, x: 20, y: 20)
        XCTAssertLessThan(covered.0, 5)
        XCTAssertLessThan(covered.1, 5)
        XCTAssertLessThan(covered.2, 5)
        XCTAssertEqual(covered.3, 255)

        let uncovered = pixel(output, x: 4, y: 4)
        XCTAssertGreaterThan(uncovered.0, 245)
        XCTAssertGreaterThan(uncovered.1, 245)
        XCTAssertGreaterThan(uncovered.2, 245)
    }

    func testCropUsesTopLeftImageCoordinates() {
        let source = stripedImage(width: 40, height: 30)
        let manager = AnnotationManager()
        let crop = NSRect(x: 7, y: 3, width: 18, height: 11)

        let output = manager.composite(onto: source, croppedTo: crop)!

        XCTAssertEqual(output.width, 18)
        XCTAssertEqual(output.height, 11)
        let expected = pixel(source, x: 12, y: 8)
        let actual = pixel(output, x: 5, y: 5)
        XCTAssertLessThanOrEqual(abs(Int(actual.0) - Int(expected.0)), 2)
        XCTAssertLessThanOrEqual(abs(Int(actual.1) - Int(expected.1)), 2)
        XCTAssertLessThanOrEqual(abs(Int(actual.2) - Int(expected.2)), 2)
        XCTAssertEqual(actual.3, expected.3)
    }
}
