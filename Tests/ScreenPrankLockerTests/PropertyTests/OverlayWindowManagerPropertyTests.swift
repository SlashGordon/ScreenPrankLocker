import XCTest
import SwiftCheck
import AppKit
@testable import ScreenPrankLocker

// Feature: screen-prank-locker, Property 1: Overlay coverage matches connected displays

/// **Validates: Requirements 1.1, 7.1**
final class OverlayWindowManagerPropertyTests: XCTestCase {

    // MARK: - NSApplication bootstrap

    override class func setUp() {
        super.setUp()
        // Ensure the shared NSApplication exists so NSWindow/NSScreen APIs work
        // in the headless test runner.
        _ = NSApplication.shared
    }

    // MARK: - Mock Screen Provider

    /// A mock ScreenProvider that returns a configurable list of NSScreen objects.
    private final class MockScreenProvider: ScreenProvider {
        let screens: [NSScreen]

        init(screens: [NSScreen]) {
            self.screens = screens
        }
    }

    // MARK: - Mutable Mock Screen Provider

    /// A mutable ScreenProvider whose screens list can be changed between calls.
    private final class MutableMockScreenProvider: ScreenProvider {
        var screens: [NSScreen]

        init(screens: [NSScreen]) {
            self.screens = screens
        }
    }

    // MARK: - Tracking Window Factory

    /// A WindowFactory that creates lightweight NSWindow instances matching the
    /// screen frame and records every creation for later assertion.
    private final class TrackingWindowFactory: WindowFactory {
        struct CreatedEntry {
            let screen: NSScreen
            let window: NSWindow
        }

        private(set) var entries: [CreatedEntry] = []

        func createOverlayWindow(for screen: NSScreen) -> NSWindow {
            let window = NSWindow(
                contentRect: screen.frame,
                styleMask: [.borderless],
                backing: .buffered,
                defer: true          // defer creation to avoid GPU work
            )
            window.isReleasedWhenClosed = false
            entries.append(CreatedEntry(screen: screen, window: window))
            return window
        }
    }

    // MARK: - Generators

    /// Generates a random screen count between 1 and 8.
    static let screenCountGen: Gen<Int> = Gen<Int>.fromElements(in: 1...8)

    /// Generates a random screen count between 1 and 4 (for display config change tests).
    static let displayChangeCountGen: Gen<Int> = Gen<Int>.fromElements(in: 1...4)

    // MARK: - Property Test

    func testOverlayCoverageMatchesConnectedDisplays() {
        // We need at least one real screen to build mock lists from.
        // In CI / headless environments NSScreen.screens may be empty;
        // skip gracefully rather than fail.
        guard let mainScreen = NSScreen.screens.first else {
            print("⚠️  No screens available – skipping overlay coverage property test")
            return
        }

        let args = CheckerArguments(maxAllowableSuccessfulTests: 100)

        property(
            "Number of overlay windows equals number of screens and each frame matches",
            arguments: args
        ) <- forAll(OverlayWindowManagerPropertyTests.screenCountGen) { (count: Int) in
            // Build a list of `count` screens using the real main screen.
            // All entries share the same frame, which is fine — the property
            // only requires count-equality and frame-equality per entry.
            let screens = Array(repeating: mainScreen, count: count)
            let provider = MockScreenProvider(screens: screens)
            let factory = TrackingWindowFactory()

            let manager = OverlayWindowManager(
                screenProvider: provider,
                windowFactory: factory
            )
            manager.createOverlays()

            // --- Assertions ---

            // 1a: overlay count == screen count
            let overlayCount = manager.overlays.count
            let countMatches = overlayCount == count

            // 1b: factory was asked to create exactly `count` windows
            let factoryCount = factory.entries.count
            let factoryCountMatches = factoryCount == count

            // 1c: each overlay window's frame matches its corresponding screen's frame
            let framesMatch = manager.overlays.allSatisfy { entry in
                entry.window.frame == entry.screen.frame
            }

            // Clean up to avoid resource leaks across iterations
            manager.destroyOverlays()

            return (countMatches <?> "overlay count (\(overlayCount)) == screen count (\(count))")
                ^&&^ (factoryCountMatches <?> "factory created (\(factoryCount)) == screen count (\(count))")
                ^&&^ (framesMatch <?> "all overlay frames match their screen frames")
        }
    }

    // Feature: screen-prank-locker, Property 9: Display configuration changes update overlay set

    /// **Validates: Requirements 7.3**
    func testDisplayConfigurationChangesUpdateOverlaySet() {
        guard let mainScreen = NSScreen.screens.first else {
            print("⚠️  No screens available – skipping display configuration change property test")
            return
        }

        let args = CheckerArguments(maxAllowableSuccessfulTests: 100)

        property(
            "After display configuration change, overlay count matches new screen count",
            arguments: args
        ) <- forAll(
            OverlayWindowManagerPropertyTests.displayChangeCountGen,
            OverlayWindowManagerPropertyTests.displayChangeCountGen
        ) { (beforeCount: Int, afterCount: Int) in
            // Build "before" screen list
            let beforeScreens = Array(repeating: mainScreen, count: beforeCount)
            let provider = MutableMockScreenProvider(screens: beforeScreens)
            let factory = TrackingWindowFactory()

            let manager = OverlayWindowManager(
                screenProvider: provider,
                windowFactory: factory
            )

            // Create initial overlays with the "before" screen count
            manager.createOverlays()
            let initialCount = manager.overlays.count
            let initialCountMatches = initialCount == beforeCount

            // Change the provider's screens to the "after" count
            let afterScreens = Array(repeating: mainScreen, count: afterCount)
            provider.screens = afterScreens

            // Handle the display configuration change
            manager.handleDisplayConfigurationChange()

            // Assert: overlay count now matches the "after" screen count
            let finalCount = manager.overlays.count
            let finalCountMatches = finalCount == afterCount

            // Clean up
            manager.destroyOverlays()

            return (initialCountMatches <?> "initial overlay count (\(initialCount)) == before count (\(beforeCount))")
                ^&&^ (finalCountMatches <?> "final overlay count (\(finalCount)) == after count (\(afterCount))")
        }
    }
}
