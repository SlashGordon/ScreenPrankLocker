// Copyright (c) 2026 SlashGordon
// Author: SlashGordon <slash.gordon.dev@gmail.com>


import AppKit
import SwiftUI

/// Custom NSWindow that intercepts key events during shortcut recording.
class ShortcutRecordingWindow: NSWindow {
    weak var viewModel: ConfigViewModel?

    override func sendEvent(_ event: NSEvent) {
        // When recording, intercept keyDown before the responder chain / menu gets it
        if let vm = viewModel, vm.isRecordingShortcut, event.type == .keyDown {
            let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            let hasModifier = modifiers.contains(.control)
                || modifiers.contains(.option)
                || modifiers.contains(.command)
                || modifiers.contains(.shift)
            if hasModifier {
                var flags = CGEventFlags()
                if modifiers.contains(.shift) { flags.insert(.maskShift) }
                if modifiers.contains(.control) { flags.insert(.maskControl) }
                if modifiers.contains(.option) { flags.insert(.maskAlternate) }
                if modifiers.contains(.command) { flags.insert(.maskCommand) }

                vm.emergencyStopShortcut = KeyCombo(modifiers: flags, keyCode: CGKeyCode(event.keyCode))
                vm.stopRecordingShortcut()
                return // swallow the event
            }
        }
        super.sendEvent(event)
    }
}

class ConfigWindowController {
    weak var delegate: ConfigWindowDelegate?
    let window: NSWindow
    let viewModel: ConfigViewModel

    init(configManager: ConfigurationManager) {
        let vm = ConfigViewModel(configManager: configManager)
        self.viewModel = vm

        let contentView = ConfigView(viewModel: vm)
        let hostingController = NSHostingController(rootView: contentView)

        let window = ShortcutRecordingWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 720),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.minSize = NSSize(width: 460, height: 600)
        window.viewModel = vm
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.backgroundColor = NSColor(red: 0.09, green: 0.07, blue: 0.14, alpha: 1.0)
        window.appearance = NSAppearance(named: .darkAqua)
        window.title = "Prank Locker"
        window.contentViewController = hostingController
        self.window = window

        vm.windowController = self
    }

    func showWindow() {
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func hideWindow() {
        window.orderOut(nil)
    }

    func populateFields(from config: PrankLockerConfig) {
        viewModel.populateFields(from: config)
    }
}
