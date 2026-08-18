import XCTest
@testable import Snap

@MainActor
final class ScrollingCaptureTests: XCTestCase {
    func testVerticalAdvanceFindsKnownOverlap() {
        let document = makeDocumentImage(width: 120, height: 360)
        let first = document.cropping(to: CGRect(x: 0, y: 0, width: 120, height: 200))!
        let second = document.cropping(to: CGRect(x: 0, y: 80, width: 120, height: 200))!

        let advance = ScrollingCapture.verticalAdvance(from: first, to: second)

        XCTAssertEqual(advance ?? 0, 80, accuracy: 5)
    }

    func testVerticalAdvanceStopsOnIdenticalFrame() {
        let image = makeDocumentImage(width: 100, height: 160)
        XCTAssertNil(ScrollingCapture.verticalAdvance(from: image, to: image))
    }

    func testStitchProducesCombinedDocumentHeight() {
        let first = makeSolidImage(width: 80, height: 100, color: .red)
        let second = makeSolidImage(width: 80, height: 100, color: .blue)

        let result = ScrollingCapture.stitch(frames: [first, second], advances: [60])

        XCTAssertEqual(result?.width, 80)
        XCTAssertEqual(result?.height, 160)
    }

    private func makeDocumentImage(width: Int, height: Int) -> CGImage {
        let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        for row in stride(from: 0, to: height, by: 4) {
            for column in stride(from: 0, to: width, by: 4) {
                let seed = (row * 17 + column * 31 + row * column) % 255
                let red = CGFloat(seed) / 255
                let green = CGFloat((seed * 7 + row) % 255) / 255
                let blue = CGFloat((seed * 13 + column) % 255) / 255
                context.setFillColor(NSColor(calibratedRed: red, green: green, blue: blue, alpha: 1).cgColor)
                context.fill(CGRect(x: column, y: row, width: 4, height: 4))
            }
        }
        return context.makeImage()!
    }

    private func makeSolidImage(width: Int, height: Int, color: NSColor) -> CGImage {
        let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        context.setFillColor(color.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()!
    }
}
