// Copyright (c) 2026 SlashGordon
// Author: SlashGordon <slash.gordon.dev@gmail.com>


import Foundation
import LocalAuthentication

/// Handles Touch ID biometric authentication for lock session deactivation.
///
/// Uses an injected `AuthenticationProvider` for testability. When listening,
/// continuously prompts for Touch ID and handles success, failure, cancel,
/// and lockout cases per the design specification.
class TouchIDAuthenticator {
    weak var delegate: TouchIDDelegate?

    private let authProvider: AuthenticationProvider
    private var reason: String = ""
    var isListening: Bool = false

    init(authProvider: AuthenticationProvider = SystemAuthenticationProvider()) {
        self.authProvider = authProvider
    }

    /// Checks if Touch ID is available on this hardware.
    func isTouchIDAvailable() -> Bool {
        return authProvider.canEvaluatePolicy()
    }

    /// Begins listening for Touch ID authentication.
    /// If Touch ID is not available, notifies delegate and returns.
    func beginListening(reason: String) {
        self.reason = reason
        isListening = true

        guard isTouchIDAvailable() else {
            delegate?.touchIDNotAvailable()
            isListening = false
            return
        }

        evaluate()
    }

    /// Stops listening for Touch ID authentication.
    func stopListening() {
        isListening = false
    }

    /// Initiates a single Touch ID evaluation and handles the result.
    private func evaluate() {
        guard isListening else { return }

        authProvider.evaluatePolicy(reason: reason) { [weak self] success, error in
            DispatchQueue.main.async {
                self?.handleEvaluationResult(success: success, error: error)
            }
        }
    }

    private func handleEvaluationResult(success: Bool, error: Error?) {
        guard isListening else { return }

        if success {
            delegate?.touchIDAuthenticationSucceeded()
            return
        }

        guard let error = error else {
            // Unexpected: failure without error. Re-initiate listening.
            evaluate()
            return
        }

        let laError = error as NSError

        if laError.domain == LAError.errorDomain {
            switch LAError.Code(rawValue: laError.code) {
            case .userCancel, .systemCancel:
                // Re-initiate after a longer delay so the prompt isn't constantly in the user's face
                DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) { [weak self] in
                    guard let self = self, self.isListening else { return }
                    self.evaluate()
                }
            case .biometryLockout:
                delegate?.touchIDAuthenticationFailed(error: error)
                stopListening()
            case .authenticationFailed:
                // Don't immediately re-prompt — wait before trying again
                delegate?.touchIDAuthenticationFailed(error: error)
                DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) { [weak self] in
                    guard let self = self, self.isListening else { return }
                    self.evaluate()
                }
            default:
                delegate?.touchIDAuthenticationFailed(error: error)
            }
        } else {
            delegate?.touchIDAuthenticationFailed(error: error)
        }
    }
}
