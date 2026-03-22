// Copyright (c) 2026 SlashGordon
// Author: SlashGordon <slash.gordon.dev@gmail.com>


import AppKit

// Handle SIGINT (Ctrl+C) and SIGTERM for clean shutdown
for sig: Int32 in [SIGINT, SIGTERM] {
    signal(sig) { _ in
        NSApplication.shared.terminate(nil)
    }
}

// Bootstrap the application with AppDelegate
let app = NSApplication.shared
app.setActivationPolicy(.regular)
let delegate = AppDelegate()
app.delegate = delegate
app.run()
