import Foundation
import ServiceManagement

final class PreferencesManager {
    static let shared = PreferencesManager()

    private let defaults = UserDefaults.standard

    private enum Keys {
        static let saveDirectory = "saveDirectory"
        static let imageFormat = "imageFormat"
        static let jpegQuality = "jpegQuality"
        static let downscaleRetina = "downscaleRetina"
        static let launchAtLogin = "launchAtLogin"
        static let copyToClipboardAfterCapture = "copyToClipboardAfterCapture"
        static let autoSaveAfterCapture = "autoSaveAfterCapture"
        static let openEditorAfterCapture = "openEditorAfterCapture"
        static let includeMouseCursor = "includeMouseCursor"
        static let showNotifications = "showNotifications"
        static let lastAnnotationColor = "lastAnnotationColor"
        static let lastLineWidth = "lastLineWidth"
        static let lastFontSize = "lastFontSize"
        static let lastTool = "lastTool"
    }

    private init() {
        registerDefaults()
        applyLaunchAtLoginSetting()
    }

    private func registerDefaults() {
        let desktop = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first!
        defaults.register(defaults: [
            Keys.saveDirectory: desktop.path,
            Keys.imageFormat: "png",
            Keys.jpegQuality: 0.85,
            Keys.downscaleRetina: false,
            Keys.launchAtLogin: false,
            Keys.copyToClipboardAfterCapture: true,
            Keys.autoSaveAfterCapture: false,
            Keys.openEditorAfterCapture: false,
            Keys.includeMouseCursor: false,
            Keys.showNotifications: true,
            Keys.lastAnnotationColor: "#FF3B30",
            Keys.lastLineWidth: 2.0,
            Keys.lastFontSize: 16.0,
        ])
    }

    var saveDirectory: URL {
        get {
            let path = defaults.string(forKey: Keys.saveDirectory) ?? ""
            return URL(fileURLWithPath: path)
        }
        set { defaults.set(newValue.path, forKey: Keys.saveDirectory) }
    }

    var imageFormat: String {
        get { defaults.string(forKey: Keys.imageFormat) ?? "png" }
        set { defaults.set(newValue, forKey: Keys.imageFormat) }
    }

    var jpegQuality: Double {
        get { defaults.double(forKey: Keys.jpegQuality) }
        set { defaults.set(newValue, forKey: Keys.jpegQuality) }
    }

    var downscaleRetina: Bool {
        get { defaults.bool(forKey: Keys.downscaleRetina) }
        set { defaults.set(newValue, forKey: Keys.downscaleRetina) }
    }

    var launchAtLogin: Bool {
        get { defaults.bool(forKey: Keys.launchAtLogin) }
        set {
            defaults.set(newValue, forKey: Keys.launchAtLogin)
            applyLaunchAtLoginSetting()
        }
    }

    var copyToClipboardAfterCapture: Bool {
        get { defaults.bool(forKey: Keys.copyToClipboardAfterCapture) }
        set { defaults.set(newValue, forKey: Keys.copyToClipboardAfterCapture) }
    }

    var autoSaveAfterCapture: Bool {
        get { defaults.bool(forKey: Keys.autoSaveAfterCapture) }
        set { defaults.set(newValue, forKey: Keys.autoSaveAfterCapture) }
    }

    var openEditorAfterCapture: Bool {
        get { defaults.bool(forKey: Keys.openEditorAfterCapture) }
        set { defaults.set(newValue, forKey: Keys.openEditorAfterCapture) }
    }

    var includeMouseCursor: Bool {
        get { defaults.bool(forKey: Keys.includeMouseCursor) }
        set { defaults.set(newValue, forKey: Keys.includeMouseCursor) }
    }

    var showNotifications: Bool {
        get { defaults.bool(forKey: Keys.showNotifications) }
        set { defaults.set(newValue, forKey: Keys.showNotifications) }
    }

    // Last-used annotation style, remembered between captures.
    var lastAnnotationColorHex: String {
        get { defaults.string(forKey: Keys.lastAnnotationColor) ?? "#FF3B30" }
        set { defaults.set(newValue, forKey: Keys.lastAnnotationColor) }
    }

    var lastLineWidth: Double {
        get { defaults.double(forKey: Keys.lastLineWidth) }
        set { defaults.set(newValue, forKey: Keys.lastLineWidth) }
    }

    var lastFontSize: Double {
        get { defaults.double(forKey: Keys.lastFontSize) }
        set { defaults.set(newValue, forKey: Keys.lastFontSize) }
    }

    var lastTool: String? {
        get { defaults.string(forKey: Keys.lastTool) }
        set { defaults.set(newValue, forKey: Keys.lastTool) }
    }

    private func applyLaunchAtLoginSetting() {
        guard #available(macOS 13.0, *) else { return }
        let enabled = launchAtLogin
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("Snap: Failed to update launch-at-login setting: \(error.localizedDescription)")
        }
    }
}
