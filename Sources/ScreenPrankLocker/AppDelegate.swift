// Copyright (c) 2026 SlashGordon
// Author: SlashGordon <slash.gordon.dev@gmail.com>


import AppKit

/// Application delegate that wires all components together and manages the app lifecycle.
class AppDelegate: NSObject, NSApplicationDelegate, ConfigWindowDelegate, LockSessionDelegate {

    private var configManager: ConfigurationManager!
    private var coordinator: LockSessionCoordinator!
    private var configWindowController: ConfigWindowController!

    // Sub-components stored as properties so they can be reused when rebuilding the coordinator
    private var windowManager: OverlayWindowManager!
    private var eventInterceptor: EventInterceptor!
    private var touchIDAuth: TouchIDAuthenticator!
    private let permissionsManager = PermissionsManager()

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Request all permissions upfront before setting up the app
        permissionsManager.requestAllPermissions { [weak self] accessibilityGranted in
            guard let self = self else { return }
            if !accessibilityGranted {
                NSLog("[AppDelegate] Accessibility not granted — app may not work correctly")
            }
            self.setupApp()
        }
    }

    private func setupApp() {
        // Load configuration
        configManager = ConfigurationManager()
        do {
            try configManager.load()
        } catch {
            NSLog("[AppDelegate] Failed to load config, using defaults: \(error)")
        }
        let config = configManager.config

        // Create all sub-components
        windowManager = OverlayWindowManager()
        eventInterceptor = EventInterceptor()
        touchIDAuth = TouchIDAuthenticator()
        let deactivationHandler = DeactivationHandler(targetSequence: config.deactivationSequence)

        // Create coordinator wiring all components
        coordinator = LockSessionCoordinator(
            windowManager: windowManager,
            eventInterceptor: eventInterceptor,
            deactivationHandler: deactivationHandler,
            touchIDAuth: touchIDAuth,
            config: config
        )
        coordinator.delegate = self

        // Create and show config window
        configWindowController = ConfigWindowController(configManager: configManager)
        configWindowController.delegate = self
        configWindowController.populateFields(from: config)
        configWindowController.showWindow()

        // Register for display configuration changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(displayConfigurationDidChange(_:)),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    func applicationWillTerminate(_ notification: Notification) {
        coordinator?.deactivate()
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func displayConfigurationDidChange(_ notification: Notification) {
        guard coordinator?.state == .active else { return }
        windowManager?.handleDisplayConfigurationChange()
    }

    // MARK: - ConfigWindowDelegate

    func configWindowDidRequestStart(with config: PrankLockerConfig) {
        configWindowController.hideWindow()

        // Rebuild coordinator with updated config
        let deactivationHandler = DeactivationHandler(targetSequence: config.deactivationSequence)
        coordinator = LockSessionCoordinator(
            windowManager: windowManager,
            eventInterceptor: eventInterceptor,
            deactivationHandler: deactivationHandler,
            touchIDAuth: touchIDAuth,
            config: config
        )
        coordinator.delegate = self

        coordinator.startSession()
    }

    // MARK: - LockSessionDelegate

    func sessionDidStart() {
        // No-op — required by protocol
    }

    func sessionDidEnd() {
        configWindowController.showWindow()
    }
}
