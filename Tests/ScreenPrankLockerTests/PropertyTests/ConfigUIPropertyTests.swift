import XCTest
import SwiftCheck
@testable import ScreenPrankLocker

// Feature: config-ui — Property-based tests for ConfigViewModel, validation, and persistence

// MARK: - SwiftCheck Arbitrary conformance for ProtectionMode

extension ProtectionMode: Arbitrary {
    public static var arbitrary: Gen<ProtectionMode> {
        return Gen<ProtectionMode>.fromElements(of: [.silent, .flash, .flashAndSound, .fartPrank, .customSounds, .webcamPrank])
    }
}

final class ConfigUIPropertyTests: XCTestCase {

    // MARK: - Helpers

    private static func makeTempConfigManager() -> ConfigurationManager {
        let tempDir = (NSTemporaryDirectory() as NSString)
            .appendingPathComponent("ConfigUIPropertyTests-\(UUID().uuidString)")
        return ConfigurationManager(configDirectoryPath: tempDir)
    }

    private static func cleanUp(manager: ConfigurationManager) {
        try? FileManager.default.removeItem(atPath: manager.configDirectoryPath)
    }

    private static func makeConfig(
        deactivationSequence: String,
        failsafeTimeoutMinutes: Int,
        protectionMode: ProtectionMode
    ) -> PrankLockerConfig {
        return PrankLockerConfig(
            activationShortcut: KeyCombo(modifiers: [.maskCommand], keyCode: 37),
            deactivationSequence: deactivationSequence,

            imageIntervalSeconds: 3.0,
            maxSimultaneousImages: 15,
            failsafeTimeoutMinutes: failsafeTimeoutMinutes,
            protectionMode: protectionMode,
            isEmergencyStopEnabled: true
        )
    }

    // MARK: - Generators

    private static let nonEmptyStringGen: Gen<String> =
        Gen<Character>.fromElements(of: Array("abcdefghijklmnopqrstuvwxyz"))
            .proliferate(withSize: 5)
            .map { String($0) }

    private static let positiveIntGen: Gen<Int> =
        Gen<Int>.fromElements(in: 1...1000)

    private static let protectionModeGen: Gen<ProtectionMode> =
        Gen<ProtectionMode>.fromElements(of: [.silent, .flash, .flashAndSound, .fartPrank, .customSounds, .webcamPrank])

    // MARK: - Mock Delegate

    private final class SpyConfigWindowDelegate: ConfigWindowDelegate {
        var startCalledWith: PrankLockerConfig?
        func configWindowDidRequestStart(with config: PrankLockerConfig) {
            startCalledWith = config
        }
    }

    // MARK: - 7.1 Property 1: Field pre-population matches config

    // Feature: config-ui, Property 1: Field pre-population matches config
    /// **Validates: Requirements 2.1, 2.2, 2.3**
    func testFieldPrePopulationMatchesConfig() {
        let args = CheckerArguments(maxAllowableSuccessfulTests: 100)

        property("Populating ConfigViewModel from a config sets all three fields correctly", arguments: args) <- forAll(
            ConfigUIPropertyTests.nonEmptyStringGen,
            ConfigUIPropertyTests.positiveIntGen,
            ConfigUIPropertyTests.protectionModeGen
        ) { (sequence: String, timeout: Int, mode: ProtectionMode) in
            let manager = ConfigUIPropertyTests.makeTempConfigManager()
            defer { ConfigUIPropertyTests.cleanUp(manager: manager) }

            let config = ConfigUIPropertyTests.makeConfig(
                deactivationSequence: sequence,
                failsafeTimeoutMinutes: timeout,
                protectionMode: mode
            )

            let viewModel = ConfigViewModel(configManager: manager)
            viewModel.populateFields(from: config)

            let seqMatch = viewModel.deactivationSequence == sequence
            let timeoutMatch = viewModel.failsafeTimeout == String(timeout)
            let modeMatch = viewModel.protectionMode == mode

            return (seqMatch <?> "deactivationSequence: expected '\(sequence)', got '\(viewModel.deactivationSequence)'")
                ^&&^ (timeoutMatch <?> "failsafeTimeout: expected '\(String(timeout))', got '\(viewModel.failsafeTimeout)'")
                ^&&^ (modeMatch <?> "protectionMode: expected \(mode), got \(viewModel.protectionMode)")
        }
    }

    // MARK: - 7.2 Property 2: Empty or whitespace-only deactivation sequence is rejected

    // Feature: config-ui, Property 2: Empty or whitespace-only deactivation sequence is rejected
    /// **Validates: Requirements 3.1**
    func testEmptyOrWhitespaceDeactivationSequenceIsRejected() {
        let args = CheckerArguments(maxAllowableSuccessfulTests: 100)

        let whitespaceGen: Gen<String> = Gen<Character>.fromElements(of: [" ", "\t", "\n"])
            .proliferate
            .map { String($0) }

        property("Whitespace-only or empty deactivation sequence causes validateFields to return nil", arguments: args) <- forAll(
            whitespaceGen
        ) { (wsString: String) in
            let manager = ConfigUIPropertyTests.makeTempConfigManager()
            defer { ConfigUIPropertyTests.cleanUp(manager: manager) }

            let viewModel = ConfigViewModel(configManager: manager)
            viewModel.deactivationSequence = wsString
            viewModel.failsafeTimeout = "5"
            viewModel.protectionMode = .flash

            let result = viewModel.validateFields()

            return (result == nil)
                <?> "validateFields() should return nil for whitespace-only string of length \(wsString.count), got non-nil"
        }
    }

    // MARK: - 7.3 Property 3: Invalid failsafe timeout is rejected

    // Feature: config-ui, Property 3: Invalid failsafe timeout is rejected
    /// **Validates: Requirements 3.2, 3.3**
    func testInvalidFailsafeTimeoutIsRejected() {
        let args = CheckerArguments(maxAllowableSuccessfulTests: 100)

        let nonIntegerStringGen: Gen<String> = Gen<String>.fromElements(of: [
            "abc", "1.5", "3.14", "", "hello", "12x", " "
        ])

        let negativeOrZeroGen: Gen<String> = Gen<Int>.fromElements(in: -100...0)
            .map { String($0) }

        let invalidTimeoutGen: Gen<String> = Gen<Bool>.pure(true).flatMap { coin -> Gen<String> in
            if coin {
                return nonIntegerStringGen
            } else {
                return negativeOrZeroGen
            }
        }

        property("Non-integer or sub-1 failsafe timeout causes validateFields to return nil", arguments: args) <- forAll(
            invalidTimeoutGen
        ) { (badTimeout: String) in
            let manager = ConfigUIPropertyTests.makeTempConfigManager()
            defer { ConfigUIPropertyTests.cleanUp(manager: manager) }

            let viewModel = ConfigViewModel(configManager: manager)
            viewModel.deactivationSequence = "validsequence"
            viewModel.failsafeTimeout = badTimeout
            viewModel.protectionMode = .flash

            let result = viewModel.validateFields()

            return (result == nil)
                <?> "validateFields() should return nil for invalid timeout '\(badTimeout)', got non-nil"
        }
    }

    // MARK: - 7.4 Property 4: Valid input triggers save and delegate

    // Feature: config-ui, Property 4: Valid input triggers save and delegate
    /// **Validates: Requirements 4.2, 4.3**
    func testValidInputTriggersSaveAndDelegate() {
        let args = CheckerArguments(maxAllowableSuccessfulTests: 100)

        property("Valid fields cause startClicked to save config and call delegate", arguments: args) <- forAll(
            ConfigUIPropertyTests.nonEmptyStringGen,
            ConfigUIPropertyTests.positiveIntGen,
            ConfigUIPropertyTests.protectionModeGen
        ) { (sequence: String, timeout: Int, mode: ProtectionMode) in
            let manager = ConfigUIPropertyTests.makeTempConfigManager()
            defer { ConfigUIPropertyTests.cleanUp(manager: manager) }

            let controller = ConfigWindowController(configManager: manager)
            let spy = SpyConfigWindowDelegate()
            controller.delegate = spy

            controller.viewModel.deactivationSequence = sequence
            controller.viewModel.failsafeTimeout = String(timeout)
            controller.viewModel.protectionMode = mode

            controller.viewModel.startClicked()

            let configSaved = manager.config.deactivationSequence == sequence
                && manager.config.failsafeTimeoutMinutes == timeout
                && manager.config.protectionMode == mode

            let delegateCalled = spy.startCalledWith != nil
                && spy.startCalledWith?.deactivationSequence == sequence
                && spy.startCalledWith?.failsafeTimeoutMinutes == timeout
                && spy.startCalledWith?.protectionMode == mode

            return (configSaved <?> "config should be saved with sequence='\(sequence)', timeout=\(timeout), mode=\(mode)")
                ^&&^ (delegateCalled <?> "delegate should be called with matching config")
        }
    }

    // MARK: - 7.5 Property 5: Config persistence round-trip

    // Feature: config-ui, Property 5: Config persistence round-trip
    /// **Validates: Requirements 5.1, 5.3**
    func testConfigPersistenceRoundTrip() {
        let args = CheckerArguments(maxAllowableSuccessfulTests: 100)

        property("Saving a config and loading it back preserves deactivation sequence, failsafe timeout, and protection mode", arguments: args) <- forAll(
            ConfigUIPropertyTests.nonEmptyStringGen,
            ConfigUIPropertyTests.positiveIntGen,
            ConfigUIPropertyTests.protectionModeGen
        ) { (sequence: String, timeout: Int, mode: ProtectionMode) in
            let tempDir = (NSTemporaryDirectory() as NSString)
                .appendingPathComponent("ConfigUIPropertyTests-roundtrip-\(UUID().uuidString)")
            let manager1 = ConfigurationManager(configDirectoryPath: tempDir)
            defer { try? FileManager.default.removeItem(atPath: tempDir) }

            manager1.config = ConfigUIPropertyTests.makeConfig(
                deactivationSequence: sequence,
                failsafeTimeoutMinutes: timeout,
                protectionMode: mode
            )

            do {
                try manager1.save()
            } catch {
                return false <?> "save() threw: \(error)"
            }

            let manager2 = ConfigurationManager(configDirectoryPath: tempDir)
            do {
                try manager2.load()
            } catch {
                return false <?> "load() threw: \(error)"
            }

            let seqMatch = manager2.config.deactivationSequence == sequence
            let timeoutMatch = manager2.config.failsafeTimeoutMinutes == timeout
            let modeMatch = manager2.config.protectionMode == mode

            return (seqMatch <?> "deactivationSequence: expected '\(sequence)', got '\(manager2.config.deactivationSequence)'")
                ^&&^ (timeoutMatch <?> "failsafeTimeoutMinutes: expected \(timeout), got \(manager2.config.failsafeTimeoutMinutes)")
                ^&&^ (modeMatch <?> "protectionMode: expected \(mode), got \(manager2.config.protectionMode)")
        }
    }
}
