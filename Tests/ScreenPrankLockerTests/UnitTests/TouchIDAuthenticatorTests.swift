import XCTest
@testable import ScreenPrankLocker
import LocalAuthentication

// MARK: - Mock AuthenticationProviders

/// Always reports Touch ID as available; evaluatePolicy calls reply with success.
final class AvailableAuthProvider: AuthenticationProvider {
    var evaluatePolicyCalled = false

    func canEvaluatePolicy() -> Bool {
        return true
    }

    func evaluatePolicy(reason: String, reply: @escaping (Bool, Error?) -> Void) {
        evaluatePolicyCalled = true
        reply(true, nil)
    }
}

/// Always reports Touch ID as unavailable.
final class UnavailableAuthProvider: AuthenticationProvider {
    func canEvaluatePolicy() -> Bool {
        return false
    }

    func evaluatePolicy(reason: String, reply: @escaping (Bool, Error?) -> Void) {
        // Should never be called when unavailable
        XCTFail("evaluatePolicy should not be called when Touch ID is unavailable")
        reply(false, nil)
    }
}

/// Reports Touch ID as available; evaluatePolicy calls reply with LAError.userCancel.
final class CancelAuthProvider: AuthenticationProvider {
    var evaluateCallCount = 0

    func canEvaluatePolicy() -> Bool {
        return true
    }

    func evaluatePolicy(reason: String, reply: @escaping (Bool, Error?) -> Void) {
        evaluateCallCount += 1
        let error = NSError(domain: LAError.errorDomain, code: LAError.userCancel.rawValue, userInfo: nil)
        reply(false, error)
    }
}

// MARK: - Mock TouchIDDelegate

final class MockTouchIDDelegate: TouchIDDelegate {
    var succeededCount = 0
    var failedErrors: [Error] = []
    var notAvailableCount = 0

    func touchIDAuthenticationSucceeded() {
        succeededCount += 1
    }

    func touchIDAuthenticationFailed(error: Error) {
        failedErrors.append(error)
    }

    func touchIDNotAvailable() {
        notAvailableCount += 1
    }
}

// MARK: - Tests

final class TouchIDAuthenticatorTests: XCTestCase {

    // MARK: - Requirement 10.1: beginListening triggers evaluatePolicy when available

    func testBeginListeningCallsEvaluatePolicyWhenAvailable() {
        let provider = AvailableAuthProvider()
        let delegate = MockTouchIDDelegate()
        let authenticator = TouchIDAuthenticator(authProvider: provider)
        authenticator.delegate = delegate

        authenticator.beginListening(reason: "Unlock prank locker")

        // evaluatePolicy should have been called synchronously since Touch ID is available
        XCTAssertTrue(provider.evaluatePolicyCalled,
                       "evaluatePolicy should be called when Touch ID is available")

        // The success reply is dispatched via DispatchQueue.main.async, so wait for it
        let expectation = expectation(description: "Delegate receives success callback")
        DispatchQueue.main.async {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        XCTAssertEqual(delegate.succeededCount, 1,
                       "Delegate should receive success callback")
    }

    // MARK: - Requirement 10.4: Not called when unavailable

    func testBeginListeningNotifiesDelegateWhenUnavailable() {
        let provider = UnavailableAuthProvider()
        let delegate = MockTouchIDDelegate()
        let authenticator = TouchIDAuthenticator(authProvider: provider)
        authenticator.delegate = delegate

        authenticator.beginListening(reason: "Unlock prank locker")

        XCTAssertEqual(delegate.notAvailableCount, 1,
                       "Delegate should be notified that Touch ID is not available")
        XCTAssertFalse(authenticator.isListening,
                       "isListening should be false when Touch ID is unavailable")
    }

    // MARK: - Requirement 10.4: Re-initiate after cancel

    func testReInitiatesListeningAfterUserCancel() {
        let provider = CancelAuthProvider()
        let delegate = MockTouchIDDelegate()
        let authenticator = TouchIDAuthenticator(authProvider: provider)
        authenticator.delegate = delegate

        authenticator.beginListening(reason: "Unlock prank locker")

        // First call happens synchronously
        XCTAssertEqual(provider.evaluateCallCount, 1,
                       "evaluatePolicy should be called once initially")

        // The cancel handler dispatches re-evaluation after 10 seconds via DispatchQueue.main.asyncAfter.
        // We need to wait for the main queue async + the 10-second delay.
        let expectation = expectation(description: "Re-initiate after cancel delay")

        DispatchQueue.main.asyncAfter(deadline: .now() + 10.5) {
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 12.0)

        // After the delay, evaluatePolicy should have been called again
        XCTAssertGreaterThan(provider.evaluateCallCount, 1,
                             "evaluatePolicy should be re-called after userCancel with delay")
        // Authenticator should still be listening
        XCTAssertTrue(authenticator.isListening,
                      "isListening should remain true after cancel re-initiation")
    }

    // MARK: - stopListening sets isListening to false

    func testStopListeningSetsIsListeningToFalse() {
        let provider = AvailableAuthProvider()
        let authenticator = TouchIDAuthenticator(authProvider: provider)

        authenticator.beginListening(reason: "Unlock prank locker")
        XCTAssertTrue(authenticator.isListening,
                      "isListening should be true after beginListening")

        authenticator.stopListening()
        XCTAssertFalse(authenticator.isListening,
                       "isListening should be false after stopListening")
    }

    // MARK: - isTouchIDAvailable reflects provider

    func testIsTouchIDAvailableReturnsProviderResult() {
        let available = TouchIDAuthenticator(authProvider: AvailableAuthProvider())
        XCTAssertTrue(available.isTouchIDAvailable())

        let unavailable = TouchIDAuthenticator(authProvider: UnavailableAuthProvider())
        XCTAssertFalse(unavailable.isTouchIDAvailable())
    }
}
