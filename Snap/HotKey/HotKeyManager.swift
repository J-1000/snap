import AppKit
@preconcurrency import ApplicationServices
import Carbon.HIToolbox

@MainActor
final class HotKeyManager {
    struct HotKey: Equatable {
        let keyCode: CGKeyCode
        let modifiers: CGEventFlags

        static let areaCapture = HotKey(
            keyCode: CGKeyCode(kVK_ANSI_4),
            modifiers: [.maskCommand, .maskShift, .maskAlternate]
        )

        static let fullScreenCapture = HotKey(
            keyCode: CGKeyCode(kVK_ANSI_3),
            modifiers: [.maskCommand, .maskShift, .maskAlternate]
        )
    }

    enum Action: Equatable, Sendable {
        case area
        case fullScreen
    }

    /// Pure modifier-match: which capture (if any) an event triggers. Requires an
    /// exact modifier match, so a superset (e.g. extra Control) is passed through.
    nonisolated static func matchedAction(keyCode: CGKeyCode, flags: CGEventFlags) -> Action? {
        let relevantFlags: CGEventFlags = [.maskCommand, .maskShift, .maskAlternate, .maskControl]
        let maskedFlags = flags.intersection(relevantFlags)
        if keyCode == HotKey.areaCapture.keyCode, maskedFlags == HotKey.areaCapture.modifiers {
            return .area
        }
        if keyCode == HotKey.fullScreenCapture.keyCode, maskedFlags == HotKey.fullScreenCapture.modifiers {
            return .fullScreen
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
                guard let action = HotKeyManager.matchedAction(keyCode: keyCode, flags: event.flags) else {
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
