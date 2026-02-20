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
