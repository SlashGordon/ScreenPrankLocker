import XCTest
@testable import ScreenPrankLocker

final class OverlayWindowConfigTests: XCTestCase {

    // MARK: - Helpers

    /// Creates an OverlayWindow for the main screen, skipping if no screen is available.
    private func makeOverlayWindow() throws -> OverlayWindow {
        guard let screen = NSScreen.screens.first else {
            throw XCTSkip("No screens available — cannot test OverlayWindow properties")
        }
        return OverlayWindow(for: screen)
    }

    // MARK: - Window Level (Req 1.2)

    func testWindowLevelIsAboveScreenSaver() throws {
        let window = try makeOverlayWindow()
        let expected = NSWindow.Level(rawValue: NSWindow.Level.screenSaver.rawValue + 1)
        XCTAssertEqual(window.level, expected, "Window level should be screenSaver + 1")
    }

    // MARK: - Transparency (Req 1.3)

    func testBackgroundColorIsClear() throws {
        let window = try makeOverlayWindow()
        XCTAssertEqual(window.backgroundColor, NSColor.clear, "Background should be clear")
    }

    func testIsOpaqueIsFalse() throws {
        let window = try makeOverlayWindow()
        XCTAssertFalse(window.isOpaque, "Window should not be opaque")
    }

    // MARK: - Mouse Event Handling (Req 2.5)

    func testIgnoresMouseEventsIsFalse() throws {
        let window = try makeOverlayWindow()
        XCTAssertFalse(window.ignoresMouseEvents, "Window should capture mouse events")
    }

    // MARK: - Style Mask (Req 1.2)

    func testStyleMaskContainsBorderless() throws {
        let window = try makeOverlayWindow()
        XCTAssertTrue(window.styleMask.contains(.borderless),
                       "Style mask should contain .borderless")
    }

    // MARK: - Collection Behavior (Req 1.2)

    func testCollectionBehaviorContainsCanJoinAllSpaces() throws {
        let window = try makeOverlayWindow()
        XCTAssertTrue(window.collectionBehavior.contains(.canJoinAllSpaces),
                       "Collection behavior should include .canJoinAllSpaces")
    }

    func testCollectionBehaviorContainsFullScreenAuxiliary() throws {
        let window = try makeOverlayWindow()
        XCTAssertTrue(window.collectionBehavior.contains(.fullScreenAuxiliary),
                       "Collection behavior should include .fullScreenAuxiliary")
    }

    func testCollectionBehaviorContainsStationary() throws {
        let window = try makeOverlayWindow()
        XCTAssertTrue(window.collectionBehavior.contains(.stationary),
                       "Collection behavior should include .stationary")
    }

    // MARK: - Shadow

    func testHasShadowIsFalse() throws {
        let window = try makeOverlayWindow()
        XCTAssertFalse(window.hasShadow, "Window should not have a shadow")
    }

    // MARK: - Frame matches screen (Req 1.1)

    func testFrameMatchesScreenFrame() throws {
        guard let screen = NSScreen.screens.first else {
            throw XCTSkip("No screens available")
        }
        let window = OverlayWindow(for: screen)
        XCTAssertEqual(window.frame, screen.frame,
                       "Window frame should match the screen's frame")
    }
}
