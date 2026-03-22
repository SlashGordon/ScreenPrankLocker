// Copyright (c) 2026 SlashGordon
// Author: SlashGordon <slash.gordon.dev@gmail.com>


import AppKit

// MARK: - Default Window Factory

/// Creates real OverlayWindow instances for production use.
final class DefaultWindowFactory: WindowFactory {
    func createOverlayWindow(for screen: NSScreen) -> NSWindow {
        return OverlayWindow(for: screen)
    }
}

// MARK: - OverlayWindowManager

/// Manages transparent overlay windows across all connected displays.
/// Uses ScreenProvider and WindowFactory protocols for testability.
class OverlayWindowManager {

    private let screenProvider: ScreenProvider
    private let windowFactory: WindowFactory

    /// Stores (screen, window) pairs. Uses an array of tuples because
    /// NSScreen does not conform to Hashable.
    private(set) var overlays: [(screen: NSScreen, window: NSWindow)] = []

    init(screenProvider: ScreenProvider = SystemScreenProvider(),
         windowFactory: WindowFactory = DefaultWindowFactory()) {
        self.screenProvider = screenProvider
        self.windowFactory = windowFactory
    }

    // MARK: - Create / Destroy

    /// Creates overlay windows on all connected screens.
    func createOverlays() {
        let screens = screenProvider.screens
        for screen in screens {
            let window = windowFactory.createOverlayWindow(for: screen)
            overlays.append((screen: screen, window: window))
            window.orderFrontRegardless()
        }
    }

    /// Destroys all overlay windows.
    func destroyOverlays() {
        for entry in overlays {
            entry.window.close()
        }
        overlays.removeAll()
    }

    // MARK: - Display Configuration Changes

    /// Adjusts overlays when displays are connected or disconnected.
    /// Tears down existing overlays and recreates them for the current screen set
    /// so the overlay set exactly matches the connected displays.
    func handleDisplayConfigurationChange() {
        destroyOverlays()
        createOverlays()
    }

    // MARK: - Image View Management

    /// Adds a prank image view at a position on a specific screen's overlay.
    func addImageView(_ imageView: NSImageView, on screen: NSScreen, at position: CGPoint) {
        guard let entry = overlays.first(where: { $0.screen.frame == screen.frame }),
              let contentView = entry.window.contentView else {
            return
        }
        imageView.frame.origin = position
        contentView.addSubview(imageView)
    }

    /// Removes a specific image view from its superview.
    func removeImageView(_ imageView: NSImageView) {
        imageView.removeFromSuperview()
    }

    // MARK: - Lookup

    /// Returns the overlay window whose frame contains the given point.
    func overlay(at point: CGPoint) -> NSWindow? {
        return overlays.first(where: { $0.window.frame.contains(point) })?.window
    }

    /// Returns the NSScreen whose frame contains the given global point.
    func screen(at point: CGPoint) -> NSScreen? {
        return overlays.first(where: { $0.screen.frame.contains(point) })?.screen
    }
}
