import Foundation

struct FileNaming {
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        return formatter
    }()

    static func defaultFilename(extension ext: String = "png") -> String {
        let timestamp = dateFormatter.string(from: Date())
        return "Snap_\(timestamp).\(ext)"
    }

    static func defaultSaveURL(extension ext: String = "png") -> URL {
        let desktop = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first!
        return desktop.appendingPathComponent(defaultFilename(extension: ext))
    }
}
