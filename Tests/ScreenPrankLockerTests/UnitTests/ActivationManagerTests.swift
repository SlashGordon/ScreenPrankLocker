import XCTest
@testable import ScreenPrankLocker

/// Mock delegate to capture activation callbacks.
final class MockActivationDelegate: ActivationDelegate {
    var requestedCount = 0

    func activationRequested() {
        requestedCount += 1
    }
}

final class ActivationManagerTests: XCTestCase {

    // MARK: - CLI Activation (Req 5.2)

    func testCheckCLIActivationReturnsFalseByDefault() {
        // CommandLine.arguments typically contains just the test runner path,
        // so --activate should not be present.
        let manager = ActivationManager()
        XCTAssertFalse(manager.checkCLIActivation(),
                       "checkCLIActivation() should return false when --activate is not in arguments")
    }

    // MARK: - Hotkey Registration (Req 5.1)

    func testRegisterHotkeyStoresCorrectKeyCombo() {
        let manager = ActivationManager()
        let combo = KeyCombo(modifiers: [.maskControl, .maskAlternate, .maskCommand], keyCode: 37)

        manager.registerHotkey(combo)

        XCTAssertNotNil(manager.registeredCombo)
        XCTAssertEqual(manager.registeredCombo?.keyCode, 37)
        XCTAssertTrue(manager.registeredCombo?.modifiers.contains(.maskControl) ?? false)
        XCTAssertTrue(manager.registeredCombo?.modifiers.contains(.maskAlternate) ?? false)
        XCTAssertTrue(manager.registeredCombo?.modifiers.contains(.maskCommand) ?? false)
    }

    func testRegisterHotkeyCreatesEventMonitor() {
        let manager = ActivationManager()
        let combo = KeyCombo(modifiers: [.maskCommand], keyCode: 0)

        manager.registerHotkey(combo)

        XCTAssertNotNil(manager.eventMonitor,
                        "registerHotkey() should create a non-nil event monitor")
    }

    // MARK: - Hotkey Unregistration

    func testUnregisterHotkeyClearsEventMonitorAndCombo() {
        let manager = ActivationManager()
        let combo = KeyCombo(modifiers: [.maskCommand], keyCode: 0)

        manager.registerHotkey(combo)
        XCTAssertNotNil(manager.eventMonitor)
        XCTAssertNotNil(manager.registeredCombo)

        manager.unregisterHotkey()

        XCTAssertNil(manager.eventMonitor,
                     "unregisterHotkey() should clear the event monitor")
        XCTAssertNil(manager.registeredCombo,
                     "unregisterHotkey() should clear the registered combo")
    }

    func testRegisterHotkeyTwiceReplacesPreviousRegistration() {
        let manager = ActivationManager()
        let combo1 = KeyCombo(modifiers: [.maskCommand], keyCode: 0)
        let combo2 = KeyCombo(modifiers: [.maskShift], keyCode: 1)

        manager.registerHotkey(combo1)
        XCTAssertEqual(manager.registeredCombo?.keyCode, 0)

        manager.registerHotkey(combo2)
        XCTAssertEqual(manager.registeredCombo?.keyCode, 1,
                       "Second registerHotkey() should replace the first combo")
        XCTAssertTrue(manager.registeredCombo?.modifiers.contains(.maskShift) ?? false)
        XCTAssertFalse(manager.registeredCombo?.modifiers.contains(.maskCommand) ?? true,
                       "Old modifier should not be present after re-registration")
        XCTAssertNotNil(manager.eventMonitor,
                        "Event monitor should still be active after re-registration")
    }
}
