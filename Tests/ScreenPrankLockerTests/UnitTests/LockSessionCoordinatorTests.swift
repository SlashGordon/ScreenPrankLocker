import XCTest
import AppKit
@testable import ScreenPrankLocker

final class LockSessionCoordinatorTests: XCTestCase {

    // MARK: - NSApplication bootstrap

    override class func setUp() {
        super.setUp()
        _ = NSApplication.shared
    }

    // MARK: - Mock Components

    /// Always returns nil from createEventTap (simulates no accessibility permission).
    private final class NilEventTapProvider: EventTapProvider {
        func createEventTap(
            location: CGEventTapLocation,
            placement: CGEventTapPlacement,
            options: CGEventTapOptions,
            eventsOfInterest: CGEventMask,
            callback: CGEventTapCallBack,
            userInfo: UnsafeMutableRawPointer?
        ) -> CFMachPort? {
            return nil
        }
        func enableTap(_ tap: CFMachPort, enable: Bool) {}
    }

    /// Returns the real main screen for overlay creation.
    private final class MockScreenProvider: ScreenProvider {
        let screens: [NSScreen]
        init() {
            self.screens = NSScreen.screens.first.map { [$0] } ?? []
        }
    }

    /// Creates lightweight NSWindow instances and tracks creation count.
    private final class TrackingWindowFactory: WindowFactory {
        private(set) var createdCount = 0
        func createOverlayWindow(for screen: NSScreen) -> NSWindow {
            createdCount += 1
            let window = NSWindow(
                contentRect: screen.frame,
                styleMask: [.borderless],
                backing: .buffered,
                defer: true
            )
            window.isReleasedWhenClosed = false
            return window
        }
    }

    /// Touch ID not available — avoids async complexity in tests.
    private final class NoOpAuthProvider: AuthenticationProvider {
        func canEvaluatePolicy() -> Bool { return false }
        func evaluatePolicy(reason: String, reply: @escaping (Bool, Error?) -> Void) {}
    }

    /// Tracks delegate calls for sessionDidStart / sessionDidEnd.
    private final class SpySessionDelegate: LockSessionDelegate {
        var startCount = 0
        var endCount = 0
        func sessionDidStart() { startCount += 1 }
        func sessionDidEnd() { endCount += 1 }
    }

    // MARK: - Helpers

    /// Builds a fully-wired coordinator with the given config, returning the coordinator and spy delegate.
    private func makeCoordinator(
        config: PrankLockerConfig = .default
    ) -> (coordinator: LockSessionCoordinator, delegate: SpySessionDelegate) {
        let components = makeCoordinatorComponents(config: config)
        let spy = SpySessionDelegate()
        components.coordinator.delegate = spy
        return (components.coordinator, spy)
    }

    private func makeCoordinatorComponents(
        config: PrankLockerConfig = .default
    ) -> (coordinator: LockSessionCoordinator, windowManager: OverlayWindowManager, eventInterceptor: EventInterceptor, touchIDAuth: TouchIDAuthenticator) {
        let screenProvider = MockScreenProvider()
        let factory = TrackingWindowFactory()
        let windowManager = OverlayWindowManager(screenProvider: screenProvider, windowFactory: factory)
        let eventInterceptor = EventInterceptor(tapProvider: NilEventTapProvider())
        let deactivationHandler = DeactivationHandler(targetSequence: config.deactivationSequence)
        let touchIDAuth = TouchIDAuthenticator(authProvider: NoOpAuthProvider())

        let coordinator = LockSessionCoordinator(
            windowManager: windowManager,
            eventInterceptor: eventInterceptor,
            deactivationHandler: deactivationHandler,
            touchIDAuth: touchIDAuth,
            config: config
        )

        return (coordinator, windowManager, eventInterceptor, touchIDAuth)
    }

    // MARK: - Test 1: startSession() transitions state from .idle to .active

    func testStartSessionTransitionsFromIdleToActive() {
        let (coordinator, _) = makeCoordinator()
        XCTAssertEqual(coordinator.state, .idle, "Initial state should be .idle")

        coordinator.startSession()
        XCTAssertEqual(coordinator.state, .active, "State should be .active after startSession()")
    }

    // MARK: - Test 2: deactivate() transitions state from .active to .idle

    func testDeactivateTransitionsFromActiveToIdle() {
        let (coordinator, _) = makeCoordinator()
        coordinator.startSession()
        XCTAssertEqual(coordinator.state, .active)

        coordinator.deactivate()
        XCTAssertEqual(coordinator.state, .idle, "State should be .idle after deactivate()")
    }

    // MARK: - Test 3: deactivate() when already idle is a no-op

    func testDeactivateWhenIdleIsNoOp() {
        let (coordinator, spy) = makeCoordinator()
        XCTAssertEqual(coordinator.state, .idle)

        coordinator.deactivate()
        XCTAssertEqual(coordinator.state, .idle, "State should remain .idle")
        XCTAssertEqual(spy.endCount, 0, "sessionDidEnd should not be called when deactivating from idle")
    }

    // MARK: - Test 4: Failsafe timer fires and deactivates the session

    func testFailsafeTimerFiresAndDeactivates() {
        // Use a config with a very short failsafe timeout (0 minutes = immediate)
        var config = PrankLockerConfig.default
        config.failsafeTimeoutMinutes = 0

        let (coordinator, spy) = makeCoordinator(config: config)
        coordinator.startSession()
        XCTAssertEqual(coordinator.state, .active)

        // Wait for the failsafe timer to fire (0 minutes = 0 seconds timeout)
        let expectation = XCTestExpectation(description: "Failsafe timer should fire and deactivate")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2.0)

        // Drain the run loop to ensure the timer fires
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))

        XCTAssertEqual(coordinator.state, .idle, "State should be .idle after failsafe timer fires")
        XCTAssertEqual(spy.endCount, 1, "sessionDidEnd should be called once after failsafe")
    }

    // MARK: - Test 5: delegate.sessionDidStart() is called on startSession()

    func testSessionDidStartDelegateCalledOnStart() {
        let (coordinator, spy) = makeCoordinator()
        XCTAssertEqual(spy.startCount, 0)

        coordinator.startSession()
        XCTAssertEqual(spy.startCount, 1, "sessionDidStart should be called exactly once")
    }

    // MARK: - Test 6: delegate.sessionDidEnd() is called on deactivate()

    func testSessionDidEndDelegateCalledOnDeactivate() {
        let (coordinator, spy) = makeCoordinator()
        coordinator.startSession()
        XCTAssertEqual(spy.endCount, 0)

        coordinator.deactivate()
        XCTAssertEqual(spy.endCount, 1, "sessionDidEnd should be called exactly once")
    }

    func testEmergencyStopHotkeyCanBeDisabledInConfig() {
        var config = PrankLockerConfig.default
        config.isEmergencyStopEnabled = false

        let (_, _, eventInterceptor, _) = makeCoordinatorComponents(config: config)
        XCTAssertNil(eventInterceptor.emergencyStopCombo, "Emergency stop combo should not be installed when disabled")
    }
}
