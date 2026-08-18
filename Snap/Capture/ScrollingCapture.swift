import AppKit

@MainActor
enum ScrollingCapture {
    typealias RegionCapture = @MainActor (NSRect, NSScreen) async throws -> CGImage
    typealias ScrollAction = @MainActor (NSPoint) -> Void

    private static let maximumFrames = 20
    private static let maximumOutputHeight = 30_000

    static func capture(
        initialImage: CGImage,
        rect: NSRect,
        screen: NSScreen,
        regionCapture: @escaping RegionCapture = { rect, screen in
            try await ScreenCapture.captureRegion(rect, screen: screen)
        },
        scroll: @escaping ScrollAction = postPageScroll
    ) async throws -> CGImage {
        var frames = [initialImage]
        var advances: [Int] = []
        var totalHeight = initialImage.height
        let scrollPoint = NSPoint(x: rect.midX, y: rect.midY)
        let originalPointer = CGEvent(source: nil)?.location

        defer {
            if let originalPointer {
                CGWarpMouseCursorPosition(originalPointer)
            }
        }

        for _ in 1..<maximumFrames {
            scroll(scrollPoint)
            try await Task.sleep(for: .milliseconds(400))
            let next = try await regionCapture(rect, screen)
            let previous = frames[frames.count - 1]
            guard let advance = verticalAdvance(from: previous, to: next),
                  advance > 0,
                  totalHeight + advance <= maximumOutputHeight else {
                break
            }
            frames.append(next)
            advances.append(advance)
            totalHeight += advance
        }

        return stitch(frames: frames, advances: advances) ?? initialImage
    }

    static func verticalAdvance(from previous: CGImage, to next: CGImage) -> Int? {
        guard previous.width == next.width, previous.height == next.height else { return nil }
        let sampleWidth = 64
        // Keep substantially more vertical detail than horizontal detail. Text
        // baselines and one-pixel separators are the strongest overlap cues;
        // collapsing them into a tiny square sample creates false matches.
        let sampleHeight = min(previous.height, 512)
        guard let previousSample = luminanceSample(previous, width: sampleWidth, height: sampleHeight),
              let nextSample = luminanceSample(next, width: sampleWidth, height: sampleHeight) else {
            return nil
        }

        let sameFrameError = meanAbsoluteError(
            previousSample,
            nextSample,
            width: sampleWidth,
            firstStartRow: 0,
            secondStartRow: 0,
            rowCount: sampleHeight
        )
        guard sameFrameError >= 2 else { return nil }

        var bestShift = 0
        var bestError = Double.greatestFiniteMagnitude
        let maximumShift = Int(Double(sampleHeight) * 0.85)
        for shift in 2...maximumShift {
            let overlap = sampleHeight - shift
            let error = meanAbsoluteError(
                previousSample,
                nextSample,
                width: sampleWidth,
                firstStartRow: shift,
                secondStartRow: 0,
                rowCount: overlap
            )
            if error < bestError {
                bestError = error
                bestShift = shift
            }
        }

        guard bestShift > 0, bestError < 18 else { return nil }
        return max(Int((Double(bestShift) / Double(sampleHeight) * Double(previous.height)).rounded()), 1)
    }

    static func stitch(frames: [CGImage], advances: [Int]) -> CGImage? {
        guard let first = frames.first,
              frames.count == advances.count + 1,
              frames.allSatisfy({ $0.width == first.width && $0.height == first.height }) else {
            return nil
        }
        let outputHeight = first.height + advances.reduce(0, +)
        guard outputHeight <= maximumOutputHeight else { return nil }
        let colorSpace = first.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB)!
        guard let context = CGContext(
            data: nil,
            width: first.width,
            height: outputHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        var remainingAdvance = advances.reduce(0, +)
        context.draw(first, in: CGRect(x: 0, y: remainingAdvance, width: first.width, height: first.height))
        for index in 1..<frames.count {
            remainingAdvance -= advances[index - 1]
            context.draw(
                frames[index],
                in: CGRect(x: 0, y: remainingAdvance, width: first.width, height: first.height)
            )
        }
        return context.makeImage()
    }

    private static func luminanceSample(_ image: CGImage, width: Int, height: Int) -> [UInt8]? {
        var rgba = [UInt8](repeating: 0, count: width * height * 4)
        let rendered = rgba.withUnsafeMutableBytes { bytes -> Bool in
            guard let baseAddress = bytes.baseAddress,
                  let context = CGContext(
                    data: baseAddress,
                    width: width,
                    height: height,
                    bitsPerComponent: 8,
                    bytesPerRow: width * 4,
                    space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                  ) else {
                return false
            }
            context.interpolationQuality = .low
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard rendered else { return nil }

        var luminance = [UInt8](repeating: 0, count: width * height)
        for pixel in 0..<(width * height) {
            let offset = pixel * 4
            let value = (Int(rgba[offset]) * 54 + Int(rgba[offset + 1]) * 183 + Int(rgba[offset + 2]) * 19) >> 8
            luminance[pixel] = UInt8(value)
        }
        return luminance
    }

    private static func meanAbsoluteError(
        _ first: [UInt8],
        _ second: [UInt8],
        width: Int,
        firstStartRow: Int,
        secondStartRow: Int,
        rowCount: Int
    ) -> Double {
        let horizontalInset = width / 10
        let comparedWidth = width - horizontalInset * 2
        var difference = 0
        for row in 0..<rowCount {
            let firstOffset = (firstStartRow + row) * width
            let secondOffset = (secondStartRow + row) * width
            for column in horizontalInset..<(width - horizontalInset) {
                difference += abs(Int(first[firstOffset + column]) - Int(second[secondOffset + column]))
            }
        }
        return Double(difference) / Double(max(rowCount * comparedWidth, 1))
    }

    private static func postPageScroll(at appKitPoint: NSPoint) {
        let primaryTop = NSScreen.screens.first?.frame.maxY ?? 0
        let quartzPoint = CGPoint(x: appKitPoint.x, y: primaryTop - appKitPoint.y)
        CGWarpMouseCursorPosition(quartzPoint)
        let amount: Int32 = -8
        CGEvent(
            scrollWheelEvent2Source: nil,
            units: .line,
            wheelCount: 1,
            wheel1: amount,
            wheel2: 0,
            wheel3: 0
        )?.post(tap: .cghidEventTap)
    }
}
