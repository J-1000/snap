import Foundation

struct FileNaming {
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        return formatter
    }()

    static var defaultSaveDirectory: URL {
        FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop")
    }

    static func defaultFilename(extension ext: String = "png") -> String {
        let timestamp = dateFormatter.string(from: Date())
        return "Snap_\(timestamp).\(ext)"
    }

    static func defaultSaveURL(extension ext: String = "png") -> URL {
        defaultSaveDirectory.appendingPathComponent(defaultFilename(extension: ext))
    }
}
