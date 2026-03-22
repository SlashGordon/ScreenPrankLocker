// Copyright (c) 2026 SlashGordon
// Author: SlashGordon <slash.gordon.dev@gmail.com>


import AppKit
import CoreGraphics

/// Installs a CGEvent tap to intercept all input events system-wide.
/// Uses an injected `EventTapProvider` for testability.
class EventInterceptor {
    weak var delegate: EventInterceptorDelegate?

    /// When set, this key combo will immediately terminate the app.
    var emergencyStopCombo: KeyCombo?

    private let tapProvider: EventTapProvider
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    /// Whether the event tap is currently installed and active.
    private(set) var isActive: Bool = false

    init(tapProvider: EventTapProvider = SystemEventTapProvider()) {
        self.tapProvider = tapProvider
    }

    // MARK: - Public API

    /// Installs the CGEvent tap. Returns false if Accessibility permission is denied
    /// (i.e. tapCreate returns nil).
    @discardableResult
    func installEventTap() -> Bool {
        guard !isActive else {
            NSLog("[EventInterceptor] installEventTap called but already active")
            return true
        }

        NSLog("[EventInterceptor] Installing event tap...")

        let selfPointer = Unmanaged.passRetained(self).toOpaque()

        guard let tap = tapProvider.createEventTap(
            location: EventTapConfig.tapLocation,
            placement: EventTapConfig.tapPlacement,
            options: EventTapConfig.tapOptions,
            eventsOfInterest: EventTapConfig.eventsOfInterest,
            callback: EventInterceptor.eventTapCallback,
            userInfo: selfPointer
        ) else {
            // Release the retained reference since we won't use it
            Unmanaged<EventInterceptor>.fromOpaque(selfPointer).release()
            NSLog("[EventInterceptor] Failed to create event tap. Accessibility permission may be denied.")
            return false
        }

        eventTap = tap

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
        tapProvider.enableTap(tap, enable: true)

        isActive = true
        return true
    }

    /// Removes the CGEvent tap and restores normal input.
    func removeEventTap() {
        guard isActive else { return }

        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
            runLoopSource = nil
        }

        if let tap = eventTap {
            CFMachPortInvalidate(tap)
            // Release the retained self reference from installEventTap
            Unmanaged<EventInterceptor>.fromOpaque(
                Unmanaged.passUnretained(self).toOpaque()
            ).release()
            eventTap = nil
        }

        isActive = false
    }

    // MARK: - Event Tap Callback

    /// The C-compatible callback for the CGEvent tap.
    /// Accesses the `EventInterceptor` instance via the `userInfo` pointer.
    static let eventTapCallback: CGEventTapCallBack = { proxy, type, event, userInfo in
        guard let userInfo = userInfo else { return Unmanaged.passRetained(event) }

        let interceptor = Unmanaged<EventInterceptor>.fromOpaque(userInfo)
            .takeUnretainedValue()

        // Handle system disabling the tap
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            NSLog("[EventInterceptor] Event tap was disabled by system. Re-enabling.")
            if let tap = interceptor.eventTap {
                interceptor.tapProvider.enableTap(tap, enable: true)
            }
            return Unmanaged.passRetained(event)
        }

        // For keyDown events, check emergency stop combo first, then feed keystroke
        // before notifying interaction attempt (so coordinator can suppress prank for matching keys)
        if type == .keyDown {
            let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
            if let combo = interceptor.emergencyStopCombo, combo.matches(event: event) {
                NSLog("[EventInterceptor] Emergency stop combo detected — terminating app")
                DispatchQueue.main.async {
                    NSApplication.shared.terminate(nil)
                }
                return Unmanaged.passRetained(event)
            }
            interceptor.delegate?.didReceiveKeystroke(keyCode)
        }

        // Notify delegate of the interaction attempt location
        let location = event.location
        interceptor.delegate?.didDetectInteractionAttempt(at: location)

        // Return nil to discard the event
        return nil
    }
}
