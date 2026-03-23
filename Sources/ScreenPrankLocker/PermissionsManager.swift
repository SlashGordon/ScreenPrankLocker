// Copyright (c) 2026 SlashGordon
// Author: SlashGordon <slash.gordon.dev@gmail.com>


import AppKit
import AVFoundation
import LocalAuthentication

/// Requests all required permissions upfront on first launch so the user isn't
/// surprised by permission dialogs later during a lock session.
final class PermissionsManager {

    /// Checks and requests all permissions, then calls the completion on the main thread.
    /// The Bool indicates whether the critical Accessibility permission is granted.
    func requestAllPermissions(completion: @escaping (Bool) -> Void) {
        // 0. Warn if the app is running from a translocated path (quarantine issue)
        if Self.isTranslocated() {
            DispatchQueue.main.async { self.showTranslocationAlert() }
        }

        // 1. Camera — triggers the system prompt if not yet decided
        requestCameraAccess {
            // 2. Touch ID — triggers biometric enrollment check
            self.probeTouchID {
                // 3. Accessibility — check (can't programmatically request; guide user if missing)
                let accessibilityGranted = self.checkAccessibility()

                DispatchQueue.main.async {
                    completion(accessibilityGranted)
                }
            }
        }
    }

    // MARK: - Camera

    private func requestCameraAccess(then next: @escaping () -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            NSLog("[Permissions] Camera: already authorized")
            next()
        case .notDetermined:
            NSLog("[Permissions] Camera: requesting access…")
            AVCaptureDevice.requestAccess(for: .video) { granted in
                NSLog("[Permissions] Camera: user responded — granted=\(granted)")
                next()
            }
        default:
            // denied or restricted — nothing we can do here
            NSLog("[Permissions] Camera: denied or restricted")
            next()
        }
    }

    // MARK: - Touch ID

    private func probeTouchID(then next: @escaping () -> Void) {
        let context = LAContext()
        var error: NSError?
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            NSLog("[Permissions] Touch ID: available")
        } else {
            NSLog("[Permissions] Touch ID: not available — \(error?.localizedDescription ?? "unknown")")
        }
        // Touch ID doesn't have a separate "request" flow; the prompt only appears
        // when evaluatePolicy is called, which is fine. Just log availability.
        next()
    }

    // MARK: - Accessibility

    /// Returns true if Accessibility access is already granted.
    /// If not, opens System Settings and shows an alert guiding the user.
    private func checkAccessibility() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)
        if trusted {
            NSLog("[Permissions] Accessibility: granted")
        } else {
            NSLog("[Permissions] Accessibility: not granted — prompting user")
            DispatchQueue.main.async {
                self.showAccessibilityAlert()
            }
        }
        return trusted
    }

    private func showAccessibilityAlert() {
        let alert = NSAlert()
        alert.messageText = "Accessibility Permission Required"
        alert.informativeText = """
            Screen Prank Locker needs Accessibility access to intercept keyboard \
            and mouse events while the screen is locked.

            macOS should have opened System Settings for you. \
            Please grant access to Screen Prank Locker, then relaunch the app.
            """
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Continue Anyway")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            // Open the Accessibility pane in System Settings
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                NSWorkspace.shared.open(url)
            }
        }
    }

    // MARK: - App Translocation Detection

    /// Detects whether the app is running from a translocated (randomized) path.
    /// macOS translocates quarantined unsigned apps, which breaks TCC permissions.
    static func isTranslocated() -> Bool {
        let bundlePath = Bundle.main.bundlePath
        // Translocated apps run from /private/var/folders/…/AppTranslocation/…
        return bundlePath.contains("/AppTranslocation/")
    }

    private func showTranslocationAlert() {
        let alert = NSAlert()
        alert.messageText = "App Is Running From a Temporary Location"
        alert.informativeText = """
            macOS is running Screen Prank Locker from a temporary location \
            (App Translocation). This prevents permissions like Accessibility \
            from being saved correctly.

            To fix this, please:
            1. Quit the app.
            2. Open Terminal and run:
               /usr/bin/xattr -dr com.apple.quarantine /Applications/ScreenPrankLocker.app
            3. Relaunch the app.
            """
        alert.alertStyle = .critical
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
