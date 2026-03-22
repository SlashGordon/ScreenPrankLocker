// Copyright (c) 2026 SlashGordon
// Author: SlashGordon <slash.gordon.dev@gmail.com>


import AppKit

/// Central coordinator that manages the lock session lifecycle.
///
/// Wires together all sub-components (overlays, event interception,
/// deactivation detection, Touch ID) and drives the session through
/// idle → active → deactivating → idle transitions.
class LockSessionCoordinator: ActivationDelegate, EventInterceptorDelegate, DeactivationDelegate, TouchIDDelegate {

    weak var delegate: LockSessionDelegate?

    private(set) var state: LockSessionState = .idle

    private let windowManager: OverlayWindowManager
    private let eventInterceptor: EventInterceptor
    private let deactivationHandler: DeactivationHandler
    private let touchIDAuth: TouchIDAuthenticator
    private let config: PrankLockerConfig
    private var failsafeTimer: Timer?
    private var directorySoundPlayer: DirectorySoundPlayer?
    private var webcamPrankManager: WebcamPrankManager?
    private var sessionStartTime: Date?
    private var suppressNextInteraction: Bool = false

    init(windowManager: OverlayWindowManager,
         eventInterceptor: EventInterceptor,
         deactivationHandler: DeactivationHandler,
         touchIDAuth: TouchIDAuthenticator,
         config: PrankLockerConfig = .default) {
        self.windowManager = windowManager
        self.eventInterceptor = eventInterceptor
        self.deactivationHandler = deactivationHandler
        self.touchIDAuth = touchIDAuth
        self.config = config

        // Wire self as delegate for sub-components
        self.eventInterceptor.delegate = self
        self.eventInterceptor.emergencyStopCombo = config.isEmergencyStopEnabled ? config.emergencyStopShortcut : nil
        if config.isSequenceDeactivationEnabled {
            self.deactivationHandler.delegate = self
        }
        if config.isTouchIDDeactivationEnabled {
            self.touchIDAuth.delegate = self
        }

        if let soundsDirectory = Self.directorySoundPath(for: config) {
            self.directorySoundPlayer = DirectorySoundPlayer(
                directory: soundsDirectory,
                cooldownSeconds: config.fartCooldownSeconds
            )
        }

        // Set up webcam prank manager if in webcam prank mode
        if config.protectionMode == .webcamPrank {
            self.webcamPrankManager = WebcamPrankManager(
                telegramBotToken: config.telegramBotToken,
                telegramChatID: config.telegramChatID
            )
        }
    }

    // MARK: - Session Lifecycle

    /// Starts a new lock session. No-op if already active (idempotent).
    func startSession() {
        guard state == .idle else {
            NSLog("[LockSession] startSession called but state is \(state) — ignoring")
            return
        }

        NSLog("[LockSession] Starting lock session")
        state = .active
        sessionStartTime = Date()

        windowManager.createOverlays()
        let tapInstalled = eventInterceptor.installEventTap()

        // Only start Touch ID if enabled and the event tap was successfully installed.
        if config.isTouchIDDeactivationEnabled && tapInstalled {
            touchIDAuth.beginListening(reason: "Unlock Screen Prank Locker")
        } else if !tapInstalled {
            NSLog("[LockSession] Event tap failed — session not fully active")
        }

        // Start failsafe timer
        let timeout = TimeInterval(config.failsafeTimeoutMinutes) * 60.0
        failsafeTimer = Timer.scheduledTimer(timeInterval: timeout,
                                             target: self,
                                             selector: #selector(failsafeExpired),
                                             userInfo: nil,
                                             repeats: false)

        delegate?.sessionDidStart()
    }

    /// Deactivates the lock session, tears down all components.
    func deactivate() {
        guard state == .active else { return }

        state = .deactivating

        eventInterceptor.removeEventTap()
        windowManager.destroyOverlays()
        touchIDAuth.stopListening()
        directorySoundPlayer?.stop()
        webcamPrankManager?.stop()

        failsafeTimer?.invalidate()
        failsafeTimer = nil

        state = .idle

        delegate?.sessionDidEnd()
    }

    /// Called when the failsafe timer expires.
    @objc func failsafeExpired() {
        failsafeTimer = nil
        deactivate()
    }

    // MARK: - ActivationDelegate

    func activationRequested() {
        startSession()
    }

    // MARK: - EventInterceptorDelegate

    func didDetectInteractionAttempt(at point: CGPoint) {
        guard state == .active else { return }

        // If the last keystroke matched the deactivation sequence, skip the prank response
        if suppressNextInteraction {
            suppressNextInteraction = false
            return
        }

        let mode = config.protectionMode
        guard mode != .silent else { return }

        DispatchQueue.main.async { [weak self] in
            guard let self = self, self.state == .active else { return }

            switch mode {
            case .flash:
                for entry in self.windowManager.overlays {
                    self.flashWhite(on: entry.window)
                }

            case .flashAndSound:
                for entry in self.windowManager.overlays {
                    self.flashWhite(on: entry.window)
                }
                if let sound = NSSound(named: NSSound.Name(self.config.alertSoundName)) {
                    sound.play()
                } else {
                    NSSound.beep()
                }

            case .fartPrank, .customSounds:
                if let start = self.sessionStartTime,
                   Date().timeIntervalSince(start) >= self.config.fartInitialDelaySeconds {
                    self.directorySoundPlayer?.playRandomSound()
                }

            case .webcamPrank:
                self.webcamPrankManager?.triggerPrank(on: self.windowManager.overlays)

            case .silent:
                break
            }
        }
    }

    /// Flashes the overlay window white by adding a temporary full-screen opaque view.
    private func flashWhite(on window: NSWindow) {
        guard let contentView = window.contentView else { return }

        let flash = NSView(frame: contentView.bounds)
        flash.autoresizingMask = [.width, .height]
        flash.wantsLayer = true
        flash.layer?.backgroundColor = CGColor(red: 1, green: 1, blue: 1, alpha: 1.0)
        contentView.addSubview(flash)
        contentView.needsDisplay = true
        window.display()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            flash.removeFromSuperview()
        }
    }

    func didReceiveKeystroke(_ keyCode: CGKeyCode) {
        guard state == .active else { return }
        let matched = deactivationHandler.feedKeystroke(keyCode)
        if matched && config.isSequenceDeactivationEnabled {
            suppressNextInteraction = true
        }
    }

    // MARK: - DeactivationDelegate

    func deactivationSequenceCompleted() {
        deactivate()
    }

    // MARK: - TouchIDDelegate

    func touchIDAuthenticationSucceeded() {
        deactivate()
    }

    func touchIDAuthenticationFailed(error: Error) {
        // Do nothing — session continues, allow further attempts
    }

    func touchIDNotAvailable() {
        // Do nothing — rely on keyboard deactivation sequence
    }

    private static func directorySoundPath(for config: PrankLockerConfig) -> String? {
        switch config.protectionMode {
        case .fartPrank:
            return config.fartSoundsDirectory
        case .customSounds:
            return config.customSoundsDirectory
        case .silent, .flash, .flashAndSound, .webcamPrank:
            return nil
        }
    }
}
