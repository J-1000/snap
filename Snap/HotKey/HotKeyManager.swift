import AppKit
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

    init() {}

    func start() {
        let eventMask: CGEventMask = (1 << CGEventType.keyDown.rawValue)

        let userInfo = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: { _, _, event, userInfo -> Unmanaged<CGEvent>? in
                guard let userInfo else { return Unmanaged.passUnretained(event) }
                let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
                guard let action = HotKeyManager.matchedAction(keyCode: keyCode, flags: event.flags) else {
                    return Unmanaged.passUnretained(event)
                }
                let manager = Unmanaged<HotKeyManager>.fromOpaque(userInfo).takeUnretainedValue()
                Task { @MainActor in
                    manager.perform(action)
                }
                return nil
            },
            userInfo: userInfo
        ) else {
            NSLog("Snap: Failed to create event tap. Ensure accessibility permissions are granted.")
            return
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(nil, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
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

    deinit {
        MainActor.assumeIsolated {
            stop()
        }
    }
}
