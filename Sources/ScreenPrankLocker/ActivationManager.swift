// Copyright (c) 2026 SlashGordon
// Author: SlashGordon <slash.gordon.dev@gmail.com>


import AppKit
import CoreGraphics

/// Handles global hotkey registration and CLI argument parsing for lock session activation.
/// Uses NSEvent.addGlobalMonitorForEvents to listen for the configured key combo.
class ActivationManager {
    weak var delegate: ActivationDelegate?

    /// The currently registered key combo, accessible for testing (internal access).
    var registeredCombo: KeyCombo?

    /// The global event monitor reference, accessible for testing (internal access).
    var eventMonitor: Any?

    /// Local event monitor for when the app is frontmost.
    private var localMonitor: Any?

    /// Registers a global keyboard shortcut that triggers activation when matched.
    /// - Parameter combo: The key combination to listen for.
    func registerHotkey(_ combo: KeyCombo) {
        // Remove any existing monitor before registering a new one
        unregisterHotkey()

        registeredCombo = combo

        // Global monitor: fires when another app is frontmost
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyEvent(event)
        }

        // Local monitor: fires when this app is frontmost
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyEvent(event)
            return event
        }
    }

    /// Unregisters the currently registered global keyboard shortcut.
    func unregisterHotkey() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
        registeredCombo = nil
    }

    private func handleKeyEvent(_ event: NSEvent) {
        guard let combo = registeredCombo else { return }

        let eventModifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let comboModifiers = nsEventModifierFlags(from: combo.modifiers)

        if eventModifiers == comboModifiers && event.keyCode == combo.keyCode {
            delegate?.activationRequested()
        }
    }

    /// Checks CLI arguments for the `--activate` flag.
    /// - Returns: `true` if `--activate` is present in `CommandLine.arguments`.
    func checkCLIActivation() -> Bool {
        return CommandLine.arguments.contains("--activate")
    }

    // MARK: - Private Helpers

    /// Converts CGEventFlags to NSEvent.ModifierFlags for comparison with NSEvent's modifierFlags.
    private func nsEventModifierFlags(from cgFlags: CGEventFlags) -> NSEvent.ModifierFlags {
        var flags = NSEvent.ModifierFlags()
        if cgFlags.contains(.maskShift) { flags.insert(.shift) }
        if cgFlags.contains(.maskControl) { flags.insert(.control) }
        if cgFlags.contains(.maskAlternate) { flags.insert(.option) }
        if cgFlags.contains(.maskCommand) { flags.insert(.command) }
        if cgFlags.contains(.maskAlphaShift) { flags.insert(.capsLock) }
        if cgFlags.contains(.maskSecondaryFn) { flags.insert(.function) }
        return flags
    }
}
