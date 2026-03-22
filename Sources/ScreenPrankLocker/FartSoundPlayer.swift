// Copyright (c) 2026 SlashGordon
// Author: SlashGordon <slash.gordon.dev@gmail.com>


import AppKit

/// Plays random sounds from a directory of MP3 files.
/// Ensures only one sound plays at a time, with a configurable cooldown between plays.
class DirectorySoundPlayer: NSObject, NSSoundDelegate {

    private let soundURLs: [URL]
    private let cooldownSeconds: TimeInterval
    private var currentSound: NSSound?
    private var isCoolingDown = false

    /// Creates a player that loads all .mp3 files from the given directory.
    /// - Parameters:
    ///   - directory: Path to the directory containing .mp3 files (supports ~)
    ///   - cooldownSeconds: Seconds to wait after a sound finishes before allowing the next
    init(directory: String, cooldownSeconds: TimeInterval = 3.0) {
        let expanded = NSString(string: directory).expandingTildeInPath
        let dirURL = URL(fileURLWithPath: expanded)
        let fm = FileManager.default

        var urls: [URL] = []
        if let enumerator = fm.enumerator(at: dirURL, includingPropertiesForKeys: nil,
                                           options: [.skipsSubdirectoryDescendants]) {
            for case let fileURL as URL in enumerator {
                if fileURL.pathExtension.lowercased() == "mp3" {
                    urls.append(fileURL)
                }
            }
        }

        self.soundURLs = urls
        self.cooldownSeconds = cooldownSeconds
        super.init()

        if urls.isEmpty {
            NSLog("[DirectorySoundPlayer] No .mp3 files found in: \(expanded)")
        } else {
            NSLog("[DirectorySoundPlayer] Loaded \(urls.count) sounds from: \(expanded)")
        }
    }

    /// Plays a random sound if not currently playing or cooling down.
    func playRandomSound() {
        guard !soundURLs.isEmpty else { return }
        guard currentSound == nil, !isCoolingDown else { return }

        let url = soundURLs.randomElement()!
        guard let sound = NSSound(contentsOf: url, byReference: true) else {
            NSLog("[DirectorySoundPlayer] Failed to load sound: \(url.lastPathComponent)")
            return
        }

        sound.delegate = self
        currentSound = sound
        sound.play()
    }

    /// Stops any currently playing sound and resets state.
    func stop() {
        currentSound?.stop()
        currentSound = nil
        isCoolingDown = false
    }

    // MARK: - NSSoundDelegate

    func sound(_ sound: NSSound, didFinishPlaying aBool: Bool) {
        currentSound = nil
        isCoolingDown = true

        DispatchQueue.main.asyncAfter(deadline: .now() + cooldownSeconds) { [weak self] in
            self?.isCoolingDown = false
        }
    }
}
