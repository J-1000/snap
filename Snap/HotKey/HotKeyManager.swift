import AppKit
import Carbon.HIToolbox

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
                guard let userInfo = userInfo else { return Unmanaged.passRetained(event) }
                let manager = Unmanaged<HotKeyManager>.fromOpaque(userInfo).takeUnretainedValue()
                return manager.handleEvent(event)
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

    private func handleEvent(_ event: CGEvent) -> Unmanaged<CGEvent>? {
        let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
        let flags = event.flags

        let relevantFlags: CGEventFlags = [.maskCommand, .maskShift, .maskAlternate, .maskControl]
        let maskedFlags = flags.intersection(relevantFlags)

        if keyCode == HotKey.areaCapture.keyCode &&
            maskedFlags == HotKey.areaCapture.modifiers {
            DispatchQueue.main.async { [weak self] in
                self?.onAreaCapture?()
            }
            return nil
        }

        if keyCode == HotKey.fullScreenCapture.keyCode &&
            maskedFlags == HotKey.fullScreenCapture.modifiers {
            DispatchQueue.main.async { [weak self] in
                self?.onFullScreenCapture?()
            }
            return nil
        }

        return Unmanaged.passRetained(event)
    }

    deinit {
        stop()
    }
}
