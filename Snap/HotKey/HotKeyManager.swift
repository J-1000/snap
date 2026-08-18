import AppKit
@preconcurrency import ApplicationServices
import Carbon.HIToolbox

@MainActor
final class HotKeyManager {
    struct HotKey: Hashable, Sendable {
        let keyCode: CGKeyCode
        let modifiers: CGEventFlags

        init(keyCode: CGKeyCode, modifiers: CGEventFlags) {
            self.keyCode = keyCode
            self.modifiers = modifiers.intersection(Self.relevantModifiers)
        }

        static func == (lhs: HotKey, rhs: HotKey) -> Bool {
            lhs.keyCode == rhs.keyCode && lhs.modifiers == rhs.modifiers
        }

        func hash(into hasher: inout Hasher) {
            hasher.combine(keyCode)
            hasher.combine(modifiers.rawValue)
        }

        static let relevantModifiers: CGEventFlags = [
            .maskCommand, .maskShift, .maskAlternate, .maskControl,
        ]

        static let areaCapture = HotKey(
            keyCode: CGKeyCode(kVK_ANSI_4),
            modifiers: [.maskCommand, .maskShift, .maskAlternate]
        )

        static let fullScreenCapture = HotKey(
            keyCode: CGKeyCode(kVK_ANSI_3),
            modifiers: [.maskCommand, .maskShift, .maskAlternate]
        )

        var displayString: String {
            var value = ""
            if modifiers.contains(.maskControl) { value += "⌃" }
            if modifiers.contains(.maskAlternate) { value += "⌥" }
            if modifiers.contains(.maskShift) { value += "⇧" }
            if modifiers.contains(.maskCommand) { value += "⌘" }
            value += Self.keyNames[keyCode] ?? "Key \(keyCode)"
            return value
        }

        private static let keyNames: [CGKeyCode: String] = [
            CGKeyCode(kVK_ANSI_A): "A", CGKeyCode(kVK_ANSI_B): "B",
            CGKeyCode(kVK_ANSI_C): "C", CGKeyCode(kVK_ANSI_D): "D",
            CGKeyCode(kVK_ANSI_E): "E", CGKeyCode(kVK_ANSI_F): "F",
            CGKeyCode(kVK_ANSI_G): "G", CGKeyCode(kVK_ANSI_H): "H",
            CGKeyCode(kVK_ANSI_I): "I", CGKeyCode(kVK_ANSI_J): "J",
            CGKeyCode(kVK_ANSI_K): "K", CGKeyCode(kVK_ANSI_L): "L",
            CGKeyCode(kVK_ANSI_M): "M", CGKeyCode(kVK_ANSI_N): "N",
            CGKeyCode(kVK_ANSI_O): "O", CGKeyCode(kVK_ANSI_P): "P",
            CGKeyCode(kVK_ANSI_Q): "Q", CGKeyCode(kVK_ANSI_R): "R",
            CGKeyCode(kVK_ANSI_S): "S", CGKeyCode(kVK_ANSI_T): "T",
            CGKeyCode(kVK_ANSI_U): "U", CGKeyCode(kVK_ANSI_V): "V",
            CGKeyCode(kVK_ANSI_W): "W", CGKeyCode(kVK_ANSI_X): "X",
            CGKeyCode(kVK_ANSI_Y): "Y", CGKeyCode(kVK_ANSI_Z): "Z",
            CGKeyCode(kVK_ANSI_0): "0", CGKeyCode(kVK_ANSI_1): "1",
            CGKeyCode(kVK_ANSI_2): "2", CGKeyCode(kVK_ANSI_3): "3",
            CGKeyCode(kVK_ANSI_4): "4", CGKeyCode(kVK_ANSI_5): "5",
            CGKeyCode(kVK_ANSI_6): "6", CGKeyCode(kVK_ANSI_7): "7",
            CGKeyCode(kVK_ANSI_8): "8", CGKeyCode(kVK_ANSI_9): "9",
            CGKeyCode(kVK_Space): "Space", CGKeyCode(kVK_Return): "Return",
            CGKeyCode(kVK_Tab): "Tab", CGKeyCode(kVK_Escape): "Escape",
            CGKeyCode(kVK_F1): "F1", CGKeyCode(kVK_F2): "F2",
            CGKeyCode(kVK_F3): "F3", CGKeyCode(kVK_F4): "F4",
            CGKeyCode(kVK_F5): "F5", CGKeyCode(kVK_F6): "F6",
            CGKeyCode(kVK_F7): "F7", CGKeyCode(kVK_F8): "F8",
            CGKeyCode(kVK_F9): "F9", CGKeyCode(kVK_F10): "F10",
            CGKeyCode(kVK_F11): "F11", CGKeyCode(kVK_F12): "F12",
        ]
    }

    enum Action: Equatable, Sendable {
        case area
        case fullScreen
    }

    /// Pure modifier-match: which capture (if any) an event triggers. Requires an
    /// exact modifier match, so a superset (e.g. extra Control) is passed through.
    nonisolated static func matchedAction(
        keyCode: CGKeyCode,
        flags: CGEventFlags,
        areaShortcut: HotKey = .areaCapture,
        fullScreenShortcut: HotKey = .fullScreenCapture
    ) -> Action? {
        let maskedFlags = flags.intersection(HotKey.relevantModifiers)
        if keyCode == areaShortcut.keyCode, maskedFlags == areaShortcut.modifiers {
            return .area
        }
        if keyCode == fullScreenShortcut.keyCode, maskedFlags == fullScreenShortcut.modifiers {
            return .fullScreen
        }
        return nil
    }

    /// Returns a user-facing reason a shortcut cannot be saved. Duplicate
    /// capture bindings and common macOS-reserved combinations are rejected.
    nonisolated static func validationError(for shortcut: HotKey, conflictingWith other: HotKey?) -> String? {
        let typingProtection: CGEventFlags = [.maskCommand, .maskAlternate, .maskControl]
        if shortcut.modifiers.intersection(typingProtection).isEmpty {
            return "Add Command, Control, or Option to avoid intercepting normal typing."
        }
        if shortcut == other {
            return "Area and full-screen capture must use different shortcuts."
        }

        let commandShift: CGEventFlags = [.maskCommand, .maskShift]
        let systemScreenshots: Set<HotKey> = [
            HotKey(keyCode: CGKeyCode(kVK_ANSI_3), modifiers: commandShift),
            HotKey(keyCode: CGKeyCode(kVK_ANSI_4), modifiers: commandShift),
            HotKey(keyCode: CGKeyCode(kVK_ANSI_5), modifiers: commandShift),
        ]
        if systemScreenshots.contains(shortcut) {
            return "That shortcut is reserved by macOS for screenshots."
        }

        let commonSystemShortcuts: Set<HotKey> = [
            HotKey(keyCode: CGKeyCode(kVK_Space), modifiers: [.maskCommand]),
            HotKey(keyCode: CGKeyCode(kVK_ANSI_Q), modifiers: [.maskCommand]),
            HotKey(keyCode: CGKeyCode(kVK_ANSI_H), modifiers: [.maskCommand]),
            HotKey(keyCode: CGKeyCode(kVK_ANSI_M), modifiers: [.maskCommand]),
            HotKey(keyCode: CGKeyCode(kVK_ANSI_W), modifiers: [.maskCommand]),
            HotKey(keyCode: CGKeyCode(kVK_Escape), modifiers: [.maskCommand, .maskAlternate]),
        ]
        if commonSystemShortcuts.contains(shortcut) {
            return "That shortcut is already used by macOS or most applications."
        }
        return nil
    }

    var onAreaCapture: (() -> Void)?
    var onFullScreenCapture: (() -> Void)?

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    var isRunning: Bool { eventTap != nil }

    init() {}

    @discardableResult
    func start() -> Bool {
        if eventTap != nil { return true }
        guard Self.hasAccessibilityPermission else { return false }

        let eventMask: CGEventMask = (1 << CGEventType.keyDown.rawValue)

        let userInfo = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: { _, type, event, userInfo -> Unmanaged<CGEvent>? in
                guard let userInfo else { return Unmanaged.passUnretained(event) }
                let manager = Unmanaged<HotKeyManager>.fromOpaque(userInfo).takeUnretainedValue()
                if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                    Task { @MainActor in
                        manager.reenableTap()
                    }
                    return Unmanaged.passUnretained(event)
                }
                let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
                let shortcuts = MainActor.assumeIsolated {
                    let prefs = PreferencesManager.shared
                    return (prefs.areaCaptureShortcut, prefs.fullScreenCaptureShortcut)
                }
                guard let action = HotKeyManager.matchedAction(
                    keyCode: keyCode,
                    flags: event.flags,
                    areaShortcut: shortcuts.0,
                    fullScreenShortcut: shortcuts.1
                ) else {
                    return Unmanaged.passUnretained(event)
                }
                Task { @MainActor in
                    manager.perform(action)
                }
                return nil
            },
            userInfo: userInfo
        ) else {
            NSLog("Snap: Failed to create event tap. Ensure accessibility permissions are granted.")
            return false
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(nil, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }

    nonisolated static var hasAccessibilityPermission: Bool {
        AXIsProcessTrusted()
    }

    /// Ask macOS to present its Accessibility trust prompt. The prompt is
    /// asynchronous; applicationDidBecomeActive retries the event tap after
    /// the user returns from System Settings.
    @discardableResult
    nonisolated static func requestAccessibilityPermission() -> Bool {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        return AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
    }

    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        runLoopSource = nil
        eventTap = nil
    }

    private func perform(_ action: Action) {
        switch action {
        case .area:
            onAreaCapture?()
        case .fullScreen:
            onFullScreenCapture?()
        }
    }

    private func reenableTap() {
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: true)
        }
    }

    deinit {
        MainActor.assumeIsolated {
            stop()
        }
    }
}
