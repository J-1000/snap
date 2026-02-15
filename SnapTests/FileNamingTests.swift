import XCTest
@testable import Snap

final class FileNamingTests: XCTestCase {

    // MARK: - defaultFilename

    func testDefaultFilenameHasSnapPrefix() {
        let filename = FileNaming.defaultFilename()
        XCTAssertTrue(filename.hasPrefix("Snap_"))
    }

    func testDefaultFilenameHasPngExtension() {
        let filename = FileNaming.defaultFilename()
        XCTAssertTrue(filename.hasSuffix(".png"))
    }

    func testDefaultFilenameWithCustomExtension() {
        let filename = FileNaming.defaultFilename(extension: "jpeg")
        XCTAssertTrue(filename.hasSuffix(".jpeg"))
        XCTAssertTrue(filename.hasPrefix("Snap_"))
    }

    func testDefaultFilenameMatchesTimestampFormat() {
        let filename = FileNaming.defaultFilename()
        // Expected: Snap_YYYY-MM-DD_HH-mm-ss.png
        let pattern = #"^Snap_\d{4}-\d{2}-\d{2}_\d{2}-\d{2}-\d{2}\.png$"#
        let regex = try! NSRegularExpression(pattern: pattern)
        let range = NSRange(filename.startIndex..., in: filename)
        XCTAssertNotNil(regex.firstMatch(in: filename, range: range),
                        "Filename '\(filename)' doesn't match expected format")
    }

    func testDefaultFilenameContainsCurrentDate() {
        let filename = FileNaming.defaultFilename()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let todayString = formatter.string(from: Date())
        XCTAssertTrue(filename.contains(todayString))
    }

    // MARK: - defaultSaveURL

    func testDefaultSaveURLPointsToDesktop() {
        let url = FileNaming.defaultSaveURL()
        let desktop = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first!
        XCTAssertEqual(url.deletingLastPathComponent().path, desktop.path)
    }

    func testDefaultSaveURLHasPngExtension() {
        let url = FileNaming.defaultSaveURL()
        XCTAssertEqual(url.pathExtension, "png")
    }

    func testDefaultSaveURLWithCustomExtension() {
        let url = FileNaming.defaultSaveURL(extension: "jpeg")
        XCTAssertEqual(url.pathExtension, "jpeg")
    }

    func testDefaultSaveURLFilenameMatchesDefaultFilename() {
        // The URL's last path component should match the filename format
        let url = FileNaming.defaultSaveURL()
        let filename = url.lastPathComponent
        XCTAssertTrue(filename.hasPrefix("Snap_"))
        XCTAssertTrue(filename.hasSuffix(".png"))
    }
}
