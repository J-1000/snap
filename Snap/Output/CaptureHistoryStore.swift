import AppKit
import ImageIO

struct CaptureHistoryEntry: Codable, Equatable, Identifiable {
    let id: UUID
    let createdAt: Date
    let filename: String
    let pixelWidth: Int
    let pixelHeight: Int
    let scaleFactor: CGFloat
}

/// Opt-in, local-only recent capture storage. The store writes PNG files and a
/// small JSON index under Application Support, and enforces a bounded count.
@MainActor
final class CaptureHistoryStore {
    static let shared = CaptureHistoryStore()

    private let directory: URL
    private let maximumEntryCount: Int
    private let isEnabled: () -> Bool
    private let fileManager: FileManager
    private let indexFilename = "index.json"

    private(set) var entries: [CaptureHistoryEntry] = []

    init(
        directory: URL = CaptureHistoryStore.defaultDirectory,
        maximumEntryCount: Int = 20,
        fileManager: FileManager = .default,
        isEnabled: @escaping () -> Bool = { PreferencesManager.shared.captureHistoryEnabled }
    ) {
        self.directory = directory
        self.maximumEntryCount = max(maximumEntryCount, 1)
        self.fileManager = fileManager
        self.isEnabled = isEnabled
        loadIndex()
    }

    @discardableResult
    func record(_ image: CGImage, scaleFactor: CGFloat) -> CaptureHistoryEntry? {
        guard isEnabled(), let data = OutputManager.pngData(from: image) else { return nil }
        do {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            let id = UUID()
            let filename = "\(id.uuidString).png"
            try data.write(to: directory.appendingPathComponent(filename), options: .atomic)
            let entry = CaptureHistoryEntry(
                id: id,
                createdAt: Date(),
                filename: filename,
                pixelWidth: image.width,
                pixelHeight: image.height,
                scaleFactor: max(scaleFactor, 1)
            )
            entries.insert(entry, at: 0)
            trimIfNeeded()
            persistIndex()
            return entry
        } catch {
            NSLog("Snap: Could not store capture history: \(error.localizedDescription)")
            return nil
        }
    }

    func image(for entry: CaptureHistoryEntry) -> CGImage? {
        let url = directory.appendingPathComponent(entry.filename)
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }

    func remove(_ entry: CaptureHistoryEntry) {
        entries.removeAll { $0.id == entry.id }
        try? fileManager.removeItem(at: directory.appendingPathComponent(entry.filename))
        persistIndex()
    }

    func clear() {
        try? fileManager.removeItem(at: directory)
        entries.removeAll()
    }

    private func loadIndex() {
        let indexURL = directory.appendingPathComponent(indexFilename)
        guard let data = try? Data(contentsOf: indexURL),
              let decoded = try? JSONDecoder().decode([CaptureHistoryEntry].self, from: data) else {
            return
        }
        entries = decoded.filter {
            fileManager.fileExists(atPath: directory.appendingPathComponent($0.filename).path)
        }
        trimIfNeeded()
    }

    private func trimIfNeeded() {
        guard entries.count > maximumEntryCount else { return }
        for entry in entries.dropFirst(maximumEntryCount) {
            try? fileManager.removeItem(at: directory.appendingPathComponent(entry.filename))
        }
        entries = Array(entries.prefix(maximumEntryCount))
    }

    private func persistIndex() {
        guard !entries.isEmpty else {
            try? fileManager.removeItem(at: directory.appendingPathComponent(indexFilename))
            return
        }
        do {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(entries)
            try data.write(to: directory.appendingPathComponent(indexFilename), options: .atomic)
        } catch {
            NSLog("Snap: Could not update capture history index: \(error.localizedDescription)")
        }
    }

    private static var defaultDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("Snap", isDirectory: true)
            .appendingPathComponent("Capture History", isDirectory: true)
    }
}
