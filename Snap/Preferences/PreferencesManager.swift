import Foundation
import CoreGraphics
import ServiceManagement

struct SavedCaptureArea: Equatable {
    let rect: NSRect
    let displayID: CGDirectDisplayID
}

@MainActor
final class PreferencesManager {
    static let shared = PreferencesManager()

    private let defaults: UserDefaults

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
        static let windowCaptureIncludesShadow = "windowCaptureIncludesShadow"
        static let windowCaptureBackground = "windowCaptureBackground"
        static let lastAreaCaptureRect = "lastAreaCaptureRect"
        static let lastAreaCaptureDisplayID = "lastAreaCaptureDisplayID"
        static let captureHDR = "captureHDR"
        static let lastTool = "lastTool"
        static let areaShortcutKeyCode = "areaShortcutKeyCode"
        static let areaShortcutModifiers = "areaShortcutModifiers"
        static let fullScreenShortcutKeyCode = "fullScreenShortcutKeyCode"
        static let fullScreenShortcutModifiers = "fullScreenShortcutModifiers"
        static let captureHistoryEnabled = "captureHistoryEnabled"
    }

    var windowCaptureIncludesShadow: Bool {
        get { defaults.object(forKey: Keys.windowCaptureIncludesShadow) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Keys.windowCaptureIncludesShadow) }
    }

    var windowCaptureBackground: String {
        get { defaults.string(forKey: Keys.windowCaptureBackground) ?? WindowCaptureBackground.transparent.rawValue }
        set { defaults.set(newValue, forKey: Keys.windowCaptureBackground) }
    }

    var lastAreaCapture: SavedCaptureArea? {
        get {
            guard let values = defaults.array(forKey: Keys.lastAreaCaptureRect) as? [Double],
                  values.count == 4,
                  let displayNumber = defaults.object(forKey: Keys.lastAreaCaptureDisplayID) as? NSNumber else {
                return nil
            }
            return SavedCaptureArea(
                rect: NSRect(x: values[0], y: values[1], width: values[2], height: values[3]),
                displayID: displayNumber.uint32Value
            )
        }
        set {
            guard let newValue else {
                defaults.removeObject(forKey: Keys.lastAreaCaptureRect)
                defaults.removeObject(forKey: Keys.lastAreaCaptureDisplayID)
                return
            }
            defaults.set(
                [newValue.rect.origin.x, newValue.rect.origin.y, newValue.rect.width, newValue.rect.height],
                forKey: Keys.lastAreaCaptureRect
            )
            defaults.set(NSNumber(value: newValue.displayID), forKey: Keys.lastAreaCaptureDisplayID)
        }
    }

    var captureHDR: Bool {
        get { defaults.bool(forKey: Keys.captureHDR) }
        set { defaults.set(newValue, forKey: Keys.captureHDR) }
    }

    var areaCaptureShortcut: HotKeyManager.HotKey {
        get {
            shortcut(
                keyCodeKey: Keys.areaShortcutKeyCode,
                modifiersKey: Keys.areaShortcutModifiers,
                fallback: .areaCapture
            )
        }
        set {
            setShortcut(
                newValue,
                keyCodeKey: Keys.areaShortcutKeyCode,
                modifiersKey: Keys.areaShortcutModifiers
            )
        }
    }

    var fullScreenCaptureShortcut: HotKeyManager.HotKey {
        get {
            shortcut(
                keyCodeKey: Keys.fullScreenShortcutKeyCode,
                modifiersKey: Keys.fullScreenShortcutModifiers,
                fallback: .fullScreenCapture
            )
        }
        set {
            setShortcut(
                newValue,
                keyCodeKey: Keys.fullScreenShortcutKeyCode,
                modifiersKey: Keys.fullScreenShortcutModifiers
            )
        }
    }

    var captureHistoryEnabled: Bool {
        get { defaults.bool(forKey: Keys.captureHistoryEnabled) }
        set { defaults.set(newValue, forKey: Keys.captureHistoryEnabled) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        registerDefaults()
    }

    private func registerDefaults() {
        defaults.register(defaults: [
            Keys.saveDirectory: FileNaming.defaultSaveDirectory.path,
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
            Keys.windowCaptureIncludesShadow: true,
            Keys.windowCaptureBackground: WindowCaptureBackground.transparent.rawValue,
            Keys.captureHDR: false,
            Keys.areaShortcutKeyCode: Int(HotKeyManager.HotKey.areaCapture.keyCode),
            Keys.areaShortcutModifiers: HotKeyManager.HotKey.areaCapture.modifiers.rawValue,
            Keys.fullScreenShortcutKeyCode: Int(HotKeyManager.HotKey.fullScreenCapture.keyCode),
            Keys.fullScreenShortcutModifiers: HotKeyManager.HotKey.fullScreenCapture.modifiers.rawValue,
            Keys.captureHistoryEnabled: false,
        ])
    }

    private func shortcut(
        keyCodeKey: String,
        modifiersKey: String,
        fallback: HotKeyManager.HotKey
    ) -> HotKeyManager.HotKey {
        guard let keyCode = defaults.object(forKey: keyCodeKey) as? NSNumber,
              let modifiers = defaults.object(forKey: modifiersKey) as? NSNumber else {
            return fallback
        }
        return HotKeyManager.HotKey(
            keyCode: CGKeyCode(keyCode.uint16Value),
            modifiers: CGEventFlags(rawValue: modifiers.uint64Value)
        )
    }

    private func setShortcut(
        _ shortcut: HotKeyManager.HotKey,
        keyCodeKey: String,
        modifiersKey: String
    ) {
        defaults.set(Int(shortcut.keyCode), forKey: keyCodeKey)
        defaults.set(shortcut.modifiers.rawValue, forKey: modifiersKey)
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
        get {
            if #available(macOS 13.0, *) {
                return SMAppService.mainApp.status == .enabled
            }
            return defaults.bool(forKey: Keys.launchAtLogin)
        }
        set {
            defaults.set(newValue, forKey: Keys.launchAtLogin)
            applyLaunchAtLoginSetting(enabled: newValue)
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

    private func applyLaunchAtLoginSetting(enabled: Bool) {
        guard #available(macOS 13.0, *) else { return }
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("Snap: Failed to update launch-at-login setting: \(error.localizedDescription)")
            OutputManager.showFailure(
                "Could not update Launch at Login. Approve it in System Settings > General > Login Items."
            )
        }
    }
}
