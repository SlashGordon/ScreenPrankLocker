// Copyright (c) 2026 SlashGordon
// Author: SlashGordon <slash.gordon.dev@gmail.com>


import Foundation
import AppKit
import Combine

class ConfigViewModel: ObservableObject {
    @Published var deactivationSequence: String = ""
    @Published var failsafeTimeout: String = ""
    @Published var protectionMode: ProtectionMode = .flash
    @Published var alertSoundName: String = "Basso"
    @Published var fartSoundsDirectory: String = "~/.prank-locker/sounds/farts/"
    @Published var customSoundsDirectory: String = "~/.prank-locker/sounds/custom/"
    @Published var fartCooldownSeconds: String = "3"
    @Published var fartInitialDelaySeconds: String = "0"
    @Published var isSequenceDeactivationEnabled: Bool = true
    @Published var isTouchIDDeactivationEnabled: Bool = true
    @Published var isEmergencyStopEnabled: Bool = true
    @Published var emergencyStopShortcut: KeyCombo = KeyCombo(modifiers: [.maskControl, .maskAlternate, .maskCommand], keyCode: 12)
    @Published var isRecordingShortcut: Bool = false
    @Published var alertMessage: String? = nil
    @Published var showAlert: Bool = false
    @Published var telegramBotToken: String = ""
    @Published var telegramChatID: String = ""


    private var eventMonitor: Any?

    let configManager: ConfigurationManager
    weak var windowController: ConfigWindowController?

    init(configManager: ConfigurationManager) {
        self.configManager = configManager
    }

    /// Populates the published fields from a given config.
    /// Requirements: 2.1, 2.2, 2.3, 5.3
    func populateFields(from config: PrankLockerConfig) {
        deactivationSequence = config.deactivationSequence
        failsafeTimeout = String(config.failsafeTimeoutMinutes)
        protectionMode = config.protectionMode
        alertSoundName = config.alertSoundName
        fartSoundsDirectory = config.fartSoundsDirectory
        customSoundsDirectory = config.customSoundsDirectory
        fartCooldownSeconds = String(Int(config.fartCooldownSeconds))
        fartInitialDelaySeconds = String(Int(config.fartInitialDelaySeconds))
        isSequenceDeactivationEnabled = config.isSequenceDeactivationEnabled
        isTouchIDDeactivationEnabled = config.isTouchIDDeactivationEnabled
        isEmergencyStopEnabled = config.isEmergencyStopEnabled
        emergencyStopShortcut = config.emergencyStopShortcut
        telegramBotToken = config.telegramBotToken ?? ""
        telegramChatID = config.telegramChatID ?? ""
    }

    /// Validates the current field values and returns an updated PrankLockerConfig on success,
    /// or nil on failure (setting alertMessage and showAlert).
    /// Requirements: 3.1, 3.2, 3.3, 3.4
    func validateFields() -> PrankLockerConfig? {
        // At least one deactivation method must be enabled
        if !isSequenceDeactivationEnabled && !isTouchIDDeactivationEnabled && !isEmergencyStopEnabled {
            alertMessage = "At least one deactivation method must be enabled."
            showAlert = true
            return nil
        }

        let trimmedSequence = deactivationSequence.trimmingCharacters(in: .whitespacesAndNewlines)
        if isSequenceDeactivationEnabled && trimmedSequence.isEmpty {
            alertMessage = "Deactivation sequence is required when sequence unlock is enabled."
            showAlert = true
            return nil
        }

        guard let timeoutValue = Int(failsafeTimeout) else {
            alertMessage = "Failsafe timeout must be a whole number."
            showAlert = true
            return nil
        }

        if timeoutValue < 1 {
            alertMessage = "Failsafe timeout must be at least 1 minute."
            showAlert = true
            return nil
        }

        if protectionMode == .fartPrank {
            let directory = fartSoundsDirectory.trimmingCharacters(in: .whitespacesAndNewlines)
            if directory.isEmpty {
                alertMessage = "Fart sounds directory is required in Fart mode."
                showAlert = true
                return nil
            }
        }

        if protectionMode == .customSounds {
            let directory = customSoundsDirectory.trimmingCharacters(in: .whitespacesAndNewlines)
            if directory.isEmpty {
                alertMessage = "Custom sounds directory is required in Custom Sounds mode."
                showAlert = true
                return nil
            }
        }

        var updatedConfig = configManager.config
        updatedConfig.deactivationSequence = trimmedSequence
        updatedConfig.failsafeTimeoutMinutes = timeoutValue
        updatedConfig.protectionMode = protectionMode
        updatedConfig.alertSoundName = alertSoundName
        updatedConfig.fartSoundsDirectory = fartSoundsDirectory
        updatedConfig.customSoundsDirectory = customSoundsDirectory
        if let cooldown = TimeInterval(fartCooldownSeconds), cooldown >= 0 {
            updatedConfig.fartCooldownSeconds = cooldown
        }
        if let initialDelay = TimeInterval(fartInitialDelaySeconds), initialDelay >= 0 {
            updatedConfig.fartInitialDelaySeconds = initialDelay
        }
        updatedConfig.isSequenceDeactivationEnabled = isSequenceDeactivationEnabled
        updatedConfig.isTouchIDDeactivationEnabled = isTouchIDDeactivationEnabled
        updatedConfig.isEmergencyStopEnabled = isEmergencyStopEnabled
        updatedConfig.emergencyStopShortcut = emergencyStopShortcut
        updatedConfig.telegramBotToken = telegramBotToken
        updatedConfig.telegramChatID = telegramChatID
        return updatedConfig
    }

    /// Called when the user clicks Start. Validates, saves, and notifies the delegate.
    /// Requirements: 4.2, 4.3, 5.1, 5.2
    func startClicked() {
        guard let validatedConfig = validateFields() else { return }

        configManager.config = validatedConfig

        do {
            try configManager.save()
        } catch {
            alertMessage = error.localizedDescription
            showAlert = true
            return
        }

        windowController?.delegate?.configWindowDidRequestStart(with: validatedConfig)
    }

    // MARK: - Shortcut Recording

    func startRecordingShortcut() {
        isRecordingShortcut = true
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }
            let modifiers = event.modifierFlags
            // Require at least one modifier key
            let hasModifier = modifiers.contains(.control)
                || modifiers.contains(.option)
                || modifiers.contains(.command)
                || modifiers.contains(.shift)
            guard hasModifier else { return nil }

            var flags = CGEventFlags()
            if modifiers.contains(.shift) { flags.insert(.maskShift) }
            if modifiers.contains(.control) { flags.insert(.maskControl) }
            if modifiers.contains(.option) { flags.insert(.maskAlternate) }
            if modifiers.contains(.command) { flags.insert(.maskCommand) }

            self.emergencyStopShortcut = KeyCombo(modifiers: flags, keyCode: CGKeyCode(event.keyCode))
            self.stopRecordingShortcut()
            return nil // swallow the event
        }
    }

    func stopRecordingShortcut() {
        isRecordingShortcut = false
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }
}
