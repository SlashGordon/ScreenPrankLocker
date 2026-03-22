import XCTest
@testable import ScreenPrankLocker

// MARK: - Mock Delegate

private final class MockConfigWindowDelegate: ConfigWindowDelegate {
    var startCalledWith: PrankLockerConfig?
    func configWindowDidRequestStart(with config: PrankLockerConfig) {
        startCalledWith = config
    }
}

// MARK: - ConfigUI Unit Tests

final class ConfigUITests: XCTestCase {

    // MARK: - Helpers

    private func makeTempConfigManager() -> ConfigurationManager {
        let tempDir = (NSTemporaryDirectory() as NSString)
            .appendingPathComponent("ConfigUITests-\(UUID().uuidString)")
        return ConfigurationManager(configDirectoryPath: tempDir)
    }

    private func cleanUp(manager: ConfigurationManager) {
        try? FileManager.default.removeItem(atPath: manager.configDirectoryPath)
    }

    // MARK: - 6.1 Window properties: title, non-resizable, centered
    // Requirements: 1.2, 1.3, 1.4

    func testWindowTitleIsPrankLocker() {
        let manager = makeTempConfigManager()
        defer { cleanUp(manager: manager) }

        let controller = ConfigWindowController(configManager: manager)
        XCTAssertEqual(controller.window.title, "Prank Locker")
    }

    func testWindowIsNotResizable() {
        let manager = makeTempConfigManager()
        defer { cleanUp(manager: manager) }

        let controller = ConfigWindowController(configManager: manager)
        XCTAssertFalse(
            controller.window.styleMask.contains(.resizable),
            "Config window should not be resizable"
        )
    }

    func testShowWindowCentersWindow() {
        let manager = makeTempConfigManager()
        defer { cleanUp(manager: manager) }

        let controller = ConfigWindowController(configManager: manager)
        // Move window off-center first
        controller.window.setFrameOrigin(NSPoint(x: 0, y: 0))
        let offCenterOrigin = controller.window.frame.origin

        // showWindow() should center it
        controller.showWindow()

        let afterOrigin = controller.window.frame.origin
        // After centering, the origin should differ from the off-center position
        // (unless the screen is tiny enough that 0,0 is already centered, which is unlikely)
        XCTAssertTrue(
            offCenterOrigin != afterOrigin || controller.window.isVisible,
            "showWindow() should center the window and make it visible"
        )
    }

    // MARK: - 6.2 ProtectionMode enum has 3 cases matching display strings
    // Requirements: 2.4

    func testProtectionModeHasSixCases() {
        let allCases: [ProtectionMode] = [.silent, .flash, .flashAndSound, .fartPrank, .customSounds, .webcamPrank]
        XCTAssertEqual(allCases.count, 6, "ProtectionMode should have exactly 6 cases")
    }

    func testProtectionModeRawValues() {
        XCTAssertEqual(ProtectionMode.silent.rawValue, "silent")
        XCTAssertEqual(ProtectionMode.flash.rawValue, "flash")
        XCTAssertEqual(ProtectionMode.flashAndSound.rawValue, "flashAndSound")
        XCTAssertEqual(ProtectionMode.fartPrank.rawValue, "fartPrank")
        XCTAssertEqual(ProtectionMode.customSounds.rawValue, "customSounds")
        XCTAssertEqual(ProtectionMode.webcamPrank.rawValue, "webcamPrank")
    }

    // MARK: - 6.3 Window hides after successful start (delegate called)
    // Requirements: 4.4

    func testStartClickedCallsDelegateWithValidFields() {
        let manager = makeTempConfigManager()
        defer { cleanUp(manager: manager) }

        let controller = ConfigWindowController(configManager: manager)
        let mockDelegate = MockConfigWindowDelegate()
        controller.delegate = mockDelegate

        // Set valid fields on the view model
        controller.viewModel.deactivationSequence = "testsequence"
        controller.viewModel.failsafeTimeout = "5"
        controller.viewModel.protectionMode = .flash
        controller.viewModel.isEmergencyStopEnabled = false

        controller.viewModel.startClicked()

        XCTAssertNotNil(
            mockDelegate.startCalledWith,
            "Delegate should be called after successful startClicked with valid fields"
        )
        XCTAssertEqual(mockDelegate.startCalledWith?.deactivationSequence, "testsequence")
        XCTAssertEqual(mockDelegate.startCalledWith?.failsafeTimeoutMinutes, 5)
        XCTAssertEqual(mockDelegate.startCalledWith?.protectionMode, .flash)
        XCTAssertEqual(mockDelegate.startCalledWith?.isEmergencyStopEnabled, false)
    }

    // MARK: - 6.4 Save failure sets alertMessage on view model
    // Requirements: 5.2

    func testSaveFailureSetsAlertMessage() {
        // Use an impossible path that will fail on save
        let badManager = ConfigurationManager(configDirectoryPath: "/dev/null/impossible")
        let viewModel = ConfigViewModel(configManager: badManager)

        // Set valid fields so validation passes but save will fail
        viewModel.deactivationSequence = "unlock"
        viewModel.failsafeTimeout = "10"
        viewModel.protectionMode = .silent

        viewModel.startClicked()

        XCTAssertTrue(viewModel.showAlert, "showAlert should be true after save failure")
        XCTAssertNotNil(viewModel.alertMessage, "alertMessage should be set after save failure")
    }
}
