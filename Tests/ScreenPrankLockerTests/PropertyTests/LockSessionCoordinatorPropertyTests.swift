import XCTest
import SwiftCheck
import AppKit
@testable import ScreenPrankLocker

// Feature: screen-prank-locker, Property 12: Failed Touch ID does not end session

/// **Validates: Requirements 10.3**
final class LockSessionCoordinatorPropertyTests: XCTestCase {

    // MARK: - NSApplication bootstrap

    override class func setUp() {
        super.setUp()
        _ = NSApplication.shared
    }

    // MARK: - Mock AuthenticationProvider

    /// A synchronous mock that always fails authentication.
    /// Tracks call count and stops responding after `maxCalls` to prevent
    /// infinite recursion through the async dispatch chain.
    private final class SyncFailAuthProvider: AuthenticationProvider {
        private(set) var callCount = 0
        private let maxCalls: Int

        init(maxCalls: Int) {
            self.maxCalls = maxCalls
        }

        func canEvaluatePolicy() -> Bool {
            return true
        }

        func evaluatePolicy(reason: String, reply: @escaping (Bool, Error?) -> Void) {
            callCount += 1
            guard callCount <= maxCalls else { return }
            let error = NSError(
                domain: "com.apple.LocalAuthentication",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Authentication failed"]
            )
            reply(false, error)
        }
    }

    // MARK: - Spy TouchIDDelegate

    private final class SpyTouchIDDelegate: TouchIDDelegate {
        var succeededCount = 0
        var failedCount = 0
        var notAvailableCount = 0

        func touchIDAuthenticationSucceeded() {
            succeededCount += 1
        }

        func touchIDAuthenticationFailed(error: Error) {
            failedCount += 1
        }

        func touchIDNotAvailable() {
            notAvailableCount += 1
        }
    }

    // MARK: - Property Test

    func testFailedTouchIDDoesNotEndSession() {
        let args = CheckerArguments(maxAllowableSuccessfulTests: 100)

        property(
            "Failed Touch ID attempts never trigger success and authenticator remains listening",
            arguments: args
        ) <- forAll(Gen<Int>.fromElements(in: 1...100)) { (attemptCount: Int) in

            let provider = SyncFailAuthProvider(maxCalls: attemptCount)
            let authenticator = TouchIDAuthenticator(authProvider: provider)
            let delegate = SpyTouchIDDelegate()
            authenticator.delegate = delegate

            // beginListening triggers the first evaluate() call.
            // The mock calls reply(false, error) synchronously.
            // handleEvaluationResult is dispatched via DispatchQueue.main.async.
            authenticator.beginListening(reason: "Test unlock")

            // Drain the main run loop to process all queued async failure handlers.
            // Each handler calls evaluate() again, which queues another async block,
            // creating a chain of exactly `attemptCount` failures.
            let deadline = Date(timeIntervalSinceNow: 10.0)
            while delegate.failedCount < attemptCount, Date() < deadline {
                RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.001))
            }

            // Assert: touchIDAuthenticationSucceeded was never called
            let neverSucceeded = delegate.succeededCount == 0

            // Assert: the authenticator is still listening (isListening == true)
            let stillListening = authenticator.isListening

            // Assert: all failures were reported
            let allFailuresReported = delegate.failedCount == attemptCount

            // Clean up to prevent further async callbacks
            authenticator.stopListening()

            return (neverSucceeded <?> "succeeded should be 0 (got \(delegate.succeededCount))")
                ^&&^ (stillListening <?> "authenticator should still be listening")
                ^&&^ (allFailuresReported <?> "expected \(attemptCount) failures (got \(delegate.failedCount))")
        }
    }
}


// MARK: - Property 8 Mocks

// Feature: screen-prank-locker, Property 8: Activation is idempotent during active session

/// **Validates: Requirements 5.3**
extension LockSessionCoordinatorPropertyTests {

    // MARK: - Mock ScreenProvider

    /// Returns a fixed list of screens.
    private final class MockScreenProvider: ScreenProvider {
        let screens: [NSScreen]
        init(screens: [NSScreen]) { self.screens = screens }
    }

    // MARK: - Nil EventTapProvider

    /// Always returns nil from createEventTap (simulates no accessibility permission).
    /// Safe for testing because the coordinator still transitions to .active.
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

    // MARK: - Tracking Window Factory

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

    // MARK: - NoOp AuthenticationProvider

    /// Touch ID not available — avoids async complexity in the test.
    private final class NoOpAuthProvider: AuthenticationProvider {
        func canEvaluatePolicy() -> Bool { return false }
        func evaluatePolicy(reason: String, reply: @escaping (Bool, Error?) -> Void) {}
    }

    // MARK: - Property 8 Test

    func testActivationIsIdempotentDuringActiveSession() {
        guard let mainScreen = NSScreen.screens.first else {
            print("⚠️  No screens available – skipping idempotent activation property test")
            return
        }

        let args = CheckerArguments(maxAllowableSuccessfulTests: 100)

        property(
            "Calling startSession() N times produces exactly one set of overlays and state remains .active",
            arguments: args
        ) <- forAll(Gen<Int>.fromElements(in: 2...50)) { (callCount: Int) in
            // Use a fixed screen count (e.g. 1 screen from the real main screen)
            let screens = [mainScreen]
            let screenProvider = MockScreenProvider(screens: screens)
            let factory = TrackingWindowFactory()

            let windowManager = OverlayWindowManager(
                screenProvider: screenProvider,
                windowFactory: factory
            )
            let eventInterceptor = EventInterceptor(tapProvider: NilEventTapProvider())
            let deactivationHandler = DeactivationHandler(targetSequence: "unlock")
            let touchIDAuth = TouchIDAuthenticator(authProvider: NoOpAuthProvider())

            let coordinator = LockSessionCoordinator(
                windowManager: windowManager,
                eventInterceptor: eventInterceptor,
                deactivationHandler: deactivationHandler,
                touchIDAuth: touchIDAuth
            )

            // Call startSession() the generated number of times
            for _ in 0..<callCount {
                coordinator.startSession()
            }

            // Assert: state remains .active (not duplicated or broken)
            let stateIsActive = coordinator.state == .active

            // Assert: only one set of overlays exists
            // The overlay count should equal the screen count (1), not multiplied by callCount
            let overlayCount = windowManager.overlays.count
            let overlayCountMatchesScreens = overlayCount == screens.count

            // Assert: the factory was only asked to create windows once (for the first startSession)
            let factoryCreatedOnce = factory.createdCount == screens.count

            // Clean up
            coordinator.deactivate()

            return (stateIsActive <?> "state should be .active (got \(coordinator.state))")
                ^&&^ (overlayCountMatchesScreens <?> "overlay count (\(overlayCount)) should equal screen count (\(screens.count)), not \(overlayCount)")
                ^&&^ (factoryCreatedOnce <?> "factory should create \(screens.count) windows, not \(factory.createdCount)")
        }
    }
}


// MARK: - Property 11 Test

// Feature: screen-prank-locker, Property 11: Either deactivation method ends the session

/// **Validates: Requirements 10.2, 10.5**
extension LockSessionCoordinatorPropertyTests {

    func testEitherDeactivationMethodEndsSession() {
        guard let mainScreen = NSScreen.screens.first else {
            print("⚠️  No screens available – skipping dual deactivation property test")
            return
        }

        let args = CheckerArguments(maxAllowableSuccessfulTests: 100)

        // Generator: Bool where true = Touch ID, false = deactivation sequence
        property(
            "Either deactivation method (Touch ID or sequence) transitions state from .active to .idle and destroys overlays",
            arguments: args
        ) <- forAll { (useTouchID: Bool) in
            let methodName = useTouchID ? "Touch ID" : "Deactivation Sequence"
            let screens = [mainScreen]
            let screenProvider = MockScreenProvider(screens: screens)
            let factory = TrackingWindowFactory()

            let windowManager = OverlayWindowManager(
                screenProvider: screenProvider,
                windowFactory: factory
            )
            let eventInterceptor = EventInterceptor(tapProvider: NilEventTapProvider())
            let deactivationHandler = DeactivationHandler(targetSequence: "unlock")
            let touchIDAuth = TouchIDAuthenticator(authProvider: NoOpAuthProvider())

            let coordinator = LockSessionCoordinator(
                windowManager: windowManager,
                eventInterceptor: eventInterceptor,
                deactivationHandler: deactivationHandler,
                touchIDAuth: touchIDAuth
            )

            // Start a session — state should be .active
            coordinator.startSession()
            let wasActive = coordinator.state == .active

            // Trigger the chosen deactivation method
            if useTouchID {
                coordinator.touchIDAuthenticationSucceeded()
            } else {
                coordinator.deactivationSequenceCompleted()
            }

            // Assert: state transitioned to .idle
            let stateIsIdle = coordinator.state == .idle

            // Assert: overlays are destroyed (empty)
            let overlaysEmpty = windowManager.overlays.isEmpty

            return (wasActive <?> "state should have been .active before deactivation")
                ^&&^ (stateIsIdle <?> "state should be .idle after \(methodName) deactivation (got \(coordinator.state))")
                ^&&^ (overlaysEmpty <?> "overlays should be empty after \(methodName) deactivation (count: \(windowManager.overlays.count))")
        }
    }
}
