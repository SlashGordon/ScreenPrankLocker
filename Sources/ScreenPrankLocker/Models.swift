// Copyright (c) 2026 SlashGordon
// Author: SlashGordon <slash.gordon.dev@gmail.com>


import AppKit
import CoreGraphics

// MARK: - KeyCombo

struct KeyCombo: Codable {
    var modifiers: CGEventFlags
    var keyCode: CGKeyCode

    enum CodingKeys: String, CodingKey {
        case modifiers
        case keyCode
    }

    // Map between CGEventFlags and human-readable string names
    private static let flagMapping: [(String, CGEventFlags)] = [
        ("shift", .maskShift),
        ("control", .maskControl),
        ("option", .maskAlternate),
        ("command", .maskCommand),
        ("capsLock", .maskAlphaShift),
        ("numericPad", .maskNumericPad),
        ("help", .maskHelp),
        ("function", .maskSecondaryFn),
    ]

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        var modifierNames: [String] = []
        for (name, flag) in KeyCombo.flagMapping {
            if modifiers.contains(flag) {
                modifierNames.append(name)
            }
        }
        try container.encode(modifierNames, forKey: .modifiers)
        try container.encode(keyCode, forKey: .keyCode)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let modifierNames = try container.decode([String].self, forKey: .modifiers)
        var flags = CGEventFlags()
        for name in modifierNames {
            if let match = KeyCombo.flagMapping.first(where: { $0.0 == name }) {
                flags.insert(match.1)
            }
        }
        self.modifiers = flags
        self.keyCode = try container.decode(CGKeyCode.self, forKey: .keyCode)
    }

    init(modifiers: CGEventFlags, keyCode: CGKeyCode) {
        self.modifiers = modifiers
        self.keyCode = keyCode
    }

    // MARK: - Display

    private static let keyCodeNames: [CGKeyCode: String] = [
        0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
        8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
        16: "Y", 17: "T", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6",
        23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0",
        30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P", 36: "↩",
        37: "L", 38: "J", 39: "'", 40: "K", 41: ";", 42: "\\", 43: ",",
        44: "/", 45: "N", 46: "M", 47: ".", 48: "⇥", 49: "Space",
        50: "`", 51: "⌫", 53: "⎋",
        96: "F5", 97: "F6", 98: "F7", 99: "F3", 100: "F8",
        101: "F9", 103: "F11", 105: "F13", 109: "F10", 111: "F12",
        118: "F4", 120: "F2", 122: "F1",
    ]

    /// Human-readable representation like "⌃⌥⌘Q"
    var displayString: String {
        var parts: [String] = []
        if modifiers.contains(.maskControl) { parts.append("⌃") }
        if modifiers.contains(.maskAlternate) { parts.append("⌥") }
        if modifiers.contains(.maskShift) { parts.append("⇧") }
        if modifiers.contains(.maskCommand) { parts.append("⌘") }
        let keyName = KeyCombo.keyCodeNames[keyCode] ?? "Key\(keyCode)"
        parts.append(keyName)
        return parts.joined()
    }

    /// Modifier-only mask for comparison (ignoring device-specific flags)
    private static let modifierMask: UInt64 =
        CGEventFlags.maskShift.rawValue
        | CGEventFlags.maskControl.rawValue
        | CGEventFlags.maskAlternate.rawValue
        | CGEventFlags.maskCommand.rawValue

    /// Check if a CGEvent matches this key combo
    func matches(event: CGEvent) -> Bool {
        let eventKeyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
        guard eventKeyCode == keyCode else { return false }
        let eventMods = event.flags.rawValue & KeyCombo.modifierMask
        let comboMods = modifiers.rawValue & KeyCombo.modifierMask
        return eventMods == comboMods
    }
}

// MARK: - Protection Mode

/// Defines how the lock screen reacts to interaction attempts.
enum ProtectionMode: String, Codable {
    /// Silent — no visual or audio feedback on interaction
    case silent
    /// Flash the screen white briefly
    case flash
    /// Flash the screen white and play a system alert sound
    case flashAndSound
    /// Play random fart sounds on interaction — no flash, with cooldown between plays
    case fartPrank
    /// Play random custom MP3s from a directory on interaction
    case customSounds
    /// Capture a webcam photo and display it on-screen with a funny caption
    case webcamPrank
}

// MARK: - PrankLockerConfig

struct PrankLockerConfig: Codable {
    var activationShortcut: KeyCombo
    var deactivationSequence: String
    var imageDirectory: String
    var imageIntervalSeconds: TimeInterval
    var maxSimultaneousImages: Int
    var failsafeTimeoutMinutes: Int
    var protectionMode: ProtectionMode
    var alertSoundName: String
    var fartSoundsDirectory: String
    var customSoundsDirectory: String
    var fartCooldownSeconds: TimeInterval
    var fartInitialDelaySeconds: TimeInterval
    var isSequenceDeactivationEnabled: Bool
    var isTouchIDDeactivationEnabled: Bool
    var isEmergencyStopEnabled: Bool
    var emergencyStopShortcut: KeyCombo
    var telegramBotToken: String?
    var telegramChatID: String?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        activationShortcut = try container.decode(KeyCombo.self, forKey: .activationShortcut)
        deactivationSequence = try container.decode(String.self, forKey: .deactivationSequence)
        imageDirectory = try container.decode(String.self, forKey: .imageDirectory)
        imageIntervalSeconds = try container.decode(TimeInterval.self, forKey: .imageIntervalSeconds)
        maxSimultaneousImages = try container.decode(Int.self, forKey: .maxSimultaneousImages)
        failsafeTimeoutMinutes = try container.decode(Int.self, forKey: .failsafeTimeoutMinutes)
        protectionMode = try container.decodeIfPresent(ProtectionMode.self, forKey: .protectionMode) ?? .flash
        alertSoundName = try container.decodeIfPresent(String.self, forKey: .alertSoundName) ?? "Basso"
        fartSoundsDirectory = try container.decodeIfPresent(String.self, forKey: .fartSoundsDirectory) ?? "~/.prank-locker/sounds/farts/"
        customSoundsDirectory = try container.decodeIfPresent(String.self, forKey: .customSoundsDirectory) ?? "~/.prank-locker/sounds/custom/"
        fartCooldownSeconds = try container.decodeIfPresent(TimeInterval.self, forKey: .fartCooldownSeconds) ?? 3.0
        fartInitialDelaySeconds = try container.decodeIfPresent(TimeInterval.self, forKey: .fartInitialDelaySeconds) ?? 0.0
        isSequenceDeactivationEnabled = try container.decodeIfPresent(Bool.self, forKey: .isSequenceDeactivationEnabled) ?? true
        isTouchIDDeactivationEnabled = try container.decodeIfPresent(Bool.self, forKey: .isTouchIDDeactivationEnabled) ?? true
        isEmergencyStopEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEmergencyStopEnabled) ?? true
        emergencyStopShortcut = try container.decodeIfPresent(KeyCombo.self, forKey: .emergencyStopShortcut)
            ?? KeyCombo(modifiers: [.maskControl, .maskAlternate, .maskCommand], keyCode: 12) // Ctrl+Option+Cmd+Q
        telegramBotToken = try container.decodeIfPresent(String.self, forKey: .telegramBotToken)
        telegramChatID = try container.decodeIfPresent(String.self, forKey: .telegramChatID)
    }

    init(activationShortcut: KeyCombo,
         deactivationSequence: String,
         imageDirectory: String,
         imageIntervalSeconds: TimeInterval,
         maxSimultaneousImages: Int,
         failsafeTimeoutMinutes: Int,
         protectionMode: ProtectionMode = .flash,
         alertSoundName: String = "Basso",
         fartSoundsDirectory: String = "~/.prank-locker/sounds/farts/",
         customSoundsDirectory: String = "~/.prank-locker/sounds/custom/",
         fartCooldownSeconds: TimeInterval = 3.0,
         fartInitialDelaySeconds: TimeInterval = 0.0,
         isSequenceDeactivationEnabled: Bool = true,
         isTouchIDDeactivationEnabled: Bool = true,
         isEmergencyStopEnabled: Bool = true,
         emergencyStopShortcut: KeyCombo = KeyCombo(modifiers: [.maskControl, .maskAlternate, .maskCommand], keyCode: 12),
         telegramBotToken: String? = nil,
         telegramChatID: String? = nil) {
        self.activationShortcut = activationShortcut
        self.deactivationSequence = deactivationSequence
        self.imageDirectory = imageDirectory
        self.imageIntervalSeconds = imageIntervalSeconds
        self.maxSimultaneousImages = maxSimultaneousImages
        self.failsafeTimeoutMinutes = failsafeTimeoutMinutes
        self.protectionMode = protectionMode
        self.alertSoundName = alertSoundName
        self.fartSoundsDirectory = fartSoundsDirectory
        self.customSoundsDirectory = customSoundsDirectory
        self.fartCooldownSeconds = fartCooldownSeconds
        self.fartInitialDelaySeconds = fartInitialDelaySeconds
        self.isSequenceDeactivationEnabled = isSequenceDeactivationEnabled
        self.isTouchIDDeactivationEnabled = isTouchIDDeactivationEnabled
        self.isEmergencyStopEnabled = isEmergencyStopEnabled
        self.emergencyStopShortcut = emergencyStopShortcut
        self.telegramBotToken = telegramBotToken
        self.telegramChatID = telegramChatID
    }

    static let `default` = PrankLockerConfig(
        activationShortcut: KeyCombo(
            modifiers: [.maskControl, .maskAlternate, .maskCommand],
            keyCode: 37  // 'L' key
        ),
        deactivationSequence: "unlock",
        imageDirectory: "~/.prank-locker/images/",
        imageIntervalSeconds: 3.0,
        maxSimultaneousImages: 15,
        failsafeTimeoutMinutes: 30,
        protectionMode: .flash,
        alertSoundName: "Basso",
        fartSoundsDirectory: "~/.prank-locker/sounds/farts/",
        customSoundsDirectory: "~/.prank-locker/sounds/custom/",
        fartCooldownSeconds: 3.0,
        fartInitialDelaySeconds: 0.0,
        isSequenceDeactivationEnabled: true,
        isTouchIDDeactivationEnabled: true,
        isEmergencyStopEnabled: true,
        emergencyStopShortcut: KeyCombo(
            modifiers: [.maskControl, .maskAlternate, .maskCommand],
            keyCode: 12  // 'Q' key
        ),
        telegramBotToken: nil,
        telegramChatID: nil
    )
}

// MARK: - Lock Session State

enum LockSessionState {
    case idle
    case active
    case deactivating
}

// MARK: - Deactivation Method

enum DeactivationMethod {
    case secretSequence
    case touchID
    case failsafeTimeout
    case sigterm
}

// MARK: - Lock Session Info

struct LockSessionInfo {
    let startTime: Date
    let config: PrankLockerConfig
    var displayedImageCount: Int
    var interactionAttemptCount: Int
    var deactivationMethod: DeactivationMethod?
}

// MARK: - Displayed Image

struct DisplayedImage {
    let id: UUID
    let image: NSImage
    let screen: NSScreen
    let position: CGPoint
    let displayedAt: Date
    weak var view: NSImageView?
}

// MARK: - Overlay Window Config

struct OverlayWindowConfig {
    static let windowLevel = NSWindow.Level(rawValue: NSWindow.Level.screenSaver.rawValue + 1)
    static let styleMask: NSWindow.StyleMask = [.borderless]
    static let backgroundColor = NSColor.clear
    static let isOpaque = false
    static let ignoresMouseEvents = false
    static let collectionBehavior: NSWindow.CollectionBehavior = [
        .canJoinAllSpaces,
        .fullScreenAuxiliary,
        .stationary,
    ]
}

// MARK: - Event Tap Config

struct EventTapConfig {
    private static func mask(for type: CGEventType) -> CGEventMask {
        1 << CGEventMask(type.rawValue)
    }

    static let eventsOfInterest: CGEventMask = {
        var m: CGEventMask = 0
        m |= mask(for: .keyDown)
        m |= mask(for: .keyUp)
        m |= mask(for: .flagsChanged)
        m |= mask(for: .leftMouseDown)
        m |= mask(for: .leftMouseUp)
        m |= mask(for: .rightMouseDown)
        m |= mask(for: .rightMouseUp)
        m |= mask(for: .mouseMoved)
        m |= mask(for: .leftMouseDragged)
        m |= mask(for: .rightMouseDragged)
        m |= mask(for: .scrollWheel)
        m |= mask(for: .otherMouseDown)
        m |= mask(for: .otherMouseUp)
        return m
    }()

    static let tapLocation: CGEventTapLocation = .cgSessionEventTap
    static let tapPlacement: CGEventTapPlacement = .headInsertEventTap
    static let tapOptions: CGEventTapOptions = .defaultTap
}
