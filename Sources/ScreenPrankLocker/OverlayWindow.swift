// Copyright (c) 2026 SlashGordon
// Author: SlashGordon <slash.gordon.dev@gmail.com>


import AppKit

/// A full-screen, always-on-top, transparent overlay window that covers a single display.
/// Configured to sit above the screensaver and Force Quit dialog, with a clear background
/// that lets the desktop show through while still capturing all mouse events.
class OverlayWindow: NSWindow {
    init(for screen: NSScreen) {
        super.init(
            contentRect: screen.frame,
            styleMask: OverlayWindowConfig.styleMask,
            backing: .buffered,
            defer: false
        )
        level = OverlayWindowConfig.windowLevel
        backgroundColor = OverlayWindowConfig.backgroundColor
        isOpaque = OverlayWindowConfig.isOpaque
        ignoresMouseEvents = OverlayWindowConfig.ignoresMouseEvents
        collectionBehavior = OverlayWindowConfig.collectionBehavior
        hasShadow = false
        isReleasedWhenClosed = false

        // Enable layer-backing so subviews with layers render correctly
        contentView?.wantsLayer = true
    }
}
