// Copyright (c) 2026 SlashGordon
// Author: SlashGordon <slash.gordon.dev@gmail.com>


import CoreGraphics

/// Tracks keystrokes to detect the secret deactivation sequence.
/// When the full sequence is typed, notifies the delegate.
final class DeactivationHandler {
    weak var delegate: DeactivationDelegate?

    private let targetSequence: String
    private(set) var buffer: String = ""

    /// Lookup table mapping macOS CGKeyCode values to lowercase characters.
    private static let keyCodeMap: [CGKeyCode: Character] = [
        // Letters
        0: "a", 1: "s", 2: "d", 3: "f", 4: "h",
        5: "g", 6: "z", 7: "x", 8: "c", 9: "v",
        11: "b", 12: "q", 13: "w", 14: "e", 15: "r",
        16: "y", 17: "t", 18: "1", 19: "2", 20: "3",
        21: "4", 22: "6", 23: "5", 24: "=", 25: "9",
        26: "7", 27: "-", 28: "8", 29: "0", 30: "]",
        31: "o", 32: "u", 33: "[", 34: "i", 35: "p",
        37: "l", 38: "j", 39: "'", 40: "k", 41: ";",
        42: "\\", 43: ",", 44: "/", 45: "n", 46: "m",
        47: ".",
    ]

    init(targetSequence: String) {
        self.targetSequence = targetSequence
    }

    /// Feeds a keystroke into the sequence detector.
    /// Appends the mapped character to the buffer if it matches the expected
    /// next character in the target sequence. Resets on mismatch, but also
    /// checks if the mismatched character could start the sequence anew.
    /// Returns `true` if the character advanced the sequence, `false` on mismatch.
    @discardableResult
    func feedKeystroke(_ keyCode: CGKeyCode) -> Bool {
        guard let char = character(for: keyCode) else { return false }
        guard !targetSequence.isEmpty else { return false }

        let targetChars = Array(targetSequence)
        let previousBufferCount = buffer.count

        // Check if the new character matches the next expected character
        let nextIndex = buffer.count
        if nextIndex < targetChars.count && char == targetChars[nextIndex] {
            buffer.append(char)
        } else {
            // Mismatch: reset buffer, but check if the new character
            // could be the start of the sequence (handle overlapping prefixes).
            // Use KMP-like fallback: find the longest suffix of (buffer + char)
            // that is a prefix of targetSequence.
            buffer.append(char)
            buffer = longestPrefixSuffix(of: buffer, matching: targetSequence)
        }

        let matched = buffer.count > previousBufferCount

        // Check if the full sequence has been entered
        if buffer == targetSequence {
            delegate?.deactivationSequenceCompleted()
            reset()
        }

        return matched
    }

    /// Resets the keystroke buffer.
    func reset() {
        buffer = ""
    }

    /// Maps a CGKeyCode to a Character using the lookup table.
    func character(for keyCode: CGKeyCode) -> Character? {
        return DeactivationHandler.keyCodeMap[keyCode]
    }

    /// Finds the longest suffix of `input` that is also a prefix of `target`.
    private func longestPrefixSuffix(of input: String, matching target: String) -> String {
        let inputChars = Array(input)
        let targetChars = Array(target)

        // Try progressively shorter suffixes of input
        let maxLen = min(inputChars.count, targetChars.count)
        for length in stride(from: maxLen, through: 1, by: -1) {
            let suffix = inputChars.suffix(length)
            let prefix = targetChars.prefix(length)
            if Array(suffix) == Array(prefix) {
                return String(suffix)
            }
        }
        return ""
    }
}
