// Copyright (c) 2026 SlashGordon
// Author: SlashGordon <slash.gordon.dev@gmail.com>


import AppKit
import CoreGraphics
import LocalAuthentication

// MARK: - System Abstraction Protocols

/// Wraps NSScreen.screens for testability
protocol ScreenProvider {
    var screens: [NSScreen] { get }
}

/// Wraps CGEvent.tapCreate functionality for testability
protocol EventTapProvider {
    func createEventTap(
        location: CGEventTapLocation,
        placement: CGEventTapPlacement,
        options: CGEventTapOptions,
        eventsOfInterest: CGEventMask,
        callback: CGEventTapCallBack,
        userInfo: UnsafeMutableRawPointer?
    ) -> CFMachPort?

    func enableTap(_ tap: CFMachPort, enable: Bool)
}

/// Wraps LAContext for testability
protocol AuthenticationProvider {
    func canEvaluatePolicy() -> Bool
    func evaluatePolicy(reason: String, reply: @escaping (Bool, Error?) -> Void)
}

/// Factory for creating overlay windows, enabling mock injection in tests
protocol WindowFactory {
    func createOverlayWindow(for screen: NSScreen) -> NSWindow
}

// MARK: - Delegate Protocols

/// Notifies when activation is requested (hotkey or CLI)
protocol ActivationDelegate: AnyObject {
    func activationRequested()
}

/// Notifies about lock session lifecycle events
protocol LockSessionDelegate: AnyObject {
    func sessionDidStart()
    func sessionDidEnd()
}

/// Notifies about intercepted input events
protocol EventInterceptorDelegate: AnyObject {
    func didDetectInteractionAttempt(at point: CGPoint)
    func didReceiveKeystroke(_ keyCode: CGKeyCode)
}

/// Notifies when the secret deactivation sequence is completed
protocol DeactivationDelegate: AnyObject {
    func deactivationSequenceCompleted()
}

/// Notifies about Touch ID authentication results
protocol TouchIDDelegate: AnyObject {
    func touchIDAuthenticationSucceeded()
    func touchIDAuthenticationFailed(error: Error)
    func touchIDNotAvailable()
}

/// Notifies when the config window requests a lock session start
protocol ConfigWindowDelegate: AnyObject {
    func configWindowDidRequestStart(with config: PrankLockerConfig)
}


// MARK: - Default System Implementations

/// Returns the real connected screens via NSScreen.screens
final class SystemScreenProvider: ScreenProvider {
    var screens: [NSScreen] {
        return NSScreen.screens
    }
}

/// Wraps the real CGEvent tap creation and enable/disable APIs
final class SystemEventTapProvider: EventTapProvider {
    func createEventTap(
        location: CGEventTapLocation,
        placement: CGEventTapPlacement,
        options: CGEventTapOptions,
        eventsOfInterest: CGEventMask,
        callback: CGEventTapCallBack,
        userInfo: UnsafeMutableRawPointer?
    ) -> CFMachPort? {
        return CGEvent.tapCreate(
            tap: location,
            place: placement,
            options: options,
            eventsOfInterest: eventsOfInterest,
            callback: callback,
            userInfo: userInfo
        )
    }

    func enableTap(_ tap: CFMachPort, enable: Bool) {
        CGEvent.tapEnable(tap: tap, enable: enable)
    }
}

/// Wraps the real LAContext for Touch ID authentication.
/// Creates a fresh LAContext for each evaluation to avoid stale context issues
/// that can block the main run loop after a cancel/failure.
final class SystemAuthenticationProvider: AuthenticationProvider {
    func canEvaluatePolicy() -> Bool {
        var error: NSError?
        return LAContext().canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }

    func evaluatePolicy(reason: String, reply: @escaping (Bool, Error?) -> Void) {
        let context = LAContext()
        context.evaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            localizedReason: reason,
            reply: reply
        )
    }
}
