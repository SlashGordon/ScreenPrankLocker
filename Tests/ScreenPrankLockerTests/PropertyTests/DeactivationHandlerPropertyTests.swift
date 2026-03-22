import XCTest
import SwiftCheck
@testable import ScreenPrankLocker

// Feature: screen-prank-locker, Property 6: Deactivation sequence detection with configurable target

/// **Validates: Requirements 4.1, 4.3**
final class DeactivationHandlerPropertyTests: XCTestCase {

    // MARK: - Reverse Lookup

    /// Builds a reverse map from Character -> CGKeyCode by scanning the handler's public `character(for:)`.
    private static let reverseKeyCodeMap: [Character: CGKeyCode] = {
        let handler = DeactivationHandler(targetSequence: "")
        var map: [Character: CGKeyCode] = [:]
        for code: CGKeyCode in 0...127 {
            if let ch = handler.character(for: code) {
                // Only include alphanumeric characters (a-z, 0-9)
                if ch.isLetter || ch.isNumber {
                    map[ch] = code
                }
            }
        }
        return map
    }()

    /// The set of characters we can generate sequences from (a-z, 0-9 that exist in the key code map).
    private static let validChars: [Character] = Array(reverseKeyCodeMap.keys).sorted()

    // MARK: - Generator

    /// Generates a random alphanumeric string of length 1-10 using only characters present in the key code map.
    static let sequenceGen: Gen<String> = {
        let charGen = Gen<Character>.fromElements(of: validChars)
        let lengthGen = Gen<Int>.fromElements(in: 1...10)
        return lengthGen.flatMap { length in
            Gen<[Character]>.compose { composer in
                (0..<length).map { _ in composer.generate(using: charGen) }
            }.map { String($0) }
        }
    }()

    // MARK: - Mock Delegate

    private final class SpyDeactivationDelegate: DeactivationDelegate {
        var completedCount = 0
        func deactivationSequenceCompleted() {
            completedCount += 1
        }
    }

    // MARK: - Property Test

    func testDeactivationSequenceDetectionWithConfigurableTarget() {
        let args = CheckerArguments(maxAllowableSuccessfulTests: 100)

        property("Feeding the exact deactivation sequence triggers the delegate exactly once", arguments: args) <- forAll(
            DeactivationHandlerPropertyTests.sequenceGen
        ) { (sequence: String) in
            let delegate = SpyDeactivationDelegate()
            let handler = DeactivationHandler(targetSequence: sequence)
            handler.delegate = delegate

            // Feed each character of the sequence using the correct CGKeyCode
            for char in sequence {
                guard let code = DeactivationHandlerPropertyTests.reverseKeyCodeMap[char] else {
                    // Should never happen since we generate from valid chars
                    return false <?> "Missing key code for character '\(char)'"
                }
                handler.feedKeystroke(code)
            }

            return (delegate.completedCount == 1)
                <?> "delegate called exactly once (got \(delegate.completedCount)) for sequence '\(sequence)'"
        }
    }

    // MARK: - Property 7

    // Feature: screen-prank-locker, Property 7: Incorrect keystroke resets sequence buffer

    /// **Validates: Requirements 4.5**
    func testIncorrectKeystrokeResetsSequenceBuffer() {
        let args = CheckerArguments(maxAllowableSuccessfulTests: 100)

        // Generator: sequences of length 2-10 (need at least 2 so we can have a prefix of 1..count-1)
        let seqGen: Gen<String> = {
            let charGen = Gen<Character>.fromElements(of: DeactivationHandlerPropertyTests.validChars)
            let lengthGen = Gen<Int>.fromElements(in: 2...10)
            return lengthGen.flatMap { length in
                Gen<[Character]>.compose { composer in
                    (0..<length).map { _ in composer.generate(using: charGen) }
                }.map { String($0) }
            }
        }()

        property("Feeding a partial prefix then a wrong character resets the buffer and does not trigger deactivation", arguments: args) <- forAll(seqGen) { (sequence: String) in
            let seqChars = Array(sequence)
            let validChars = DeactivationHandlerPropertyTests.validChars
            let reverseMap = DeactivationHandlerPropertyTests.reverseKeyCodeMap

            // Pick a random prefix length from 1 to sequence.count - 1
            let prefixLength = Int.random(in: 1...(seqChars.count - 1))
            let nextExpectedChar = seqChars[prefixLength]

            // Find a wrong character: any valid char that is NOT the next expected character
            let wrongCandidates = validChars.filter { $0 != nextExpectedChar }
            guard !wrongCandidates.isEmpty else {
                // Only one valid char exists and it matches — degenerate case, skip
                return true <?> "skipped: no wrong character available"
            }
            let wrongChar = wrongCandidates.randomElement()!

            let delegate = SpyDeactivationDelegate()
            let handler = DeactivationHandler(targetSequence: sequence)
            handler.delegate = delegate

            // Feed the prefix characters
            for i in 0..<prefixLength {
                guard let code = reverseMap[seqChars[i]] else {
                    return false <?> "Missing key code for character '\(seqChars[i])'"
                }
                handler.feedKeystroke(code)
            }

            // Feed the wrong character
            guard let wrongCode = reverseMap[wrongChar] else {
                return false <?> "Missing key code for wrong character '\(wrongChar)'"
            }
            handler.feedKeystroke(wrongCode)

            // Assert: delegate was NOT called (deactivation not triggered)
            let delegateNotCalled = delegate.completedCount == 0

            // Assert: buffer was reset — it must NOT contain the full prefix + wrong char.
            // The handler uses KMP-like fallback, so the buffer may contain a valid
            // prefix of the target sequence (longest suffix of prefix+wrongChar that
            // is a prefix of target), but it must be shorter than prefixLength + 1.
            let bufferReset = handler.buffer.count < (prefixLength + 1)

            return (delegateNotCalled <?> "delegate should not be called (got \(delegate.completedCount))")
                ^&&^ (bufferReset <?> "buffer should be reset (buffer='\(handler.buffer)', length=\(handler.buffer.count), expected < \(prefixLength + 1))")
        }
    }
}
