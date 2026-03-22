import XCTest
@testable import ScreenPrankLocker

/// Mock delegate to capture deactivation callbacks.
final class MockDeactivationDelegate: DeactivationDelegate {
    var completedCount = 0

    func deactivationSequenceCompleted() {
        completedCount += 1
    }
}

final class DeactivationHandlerTests: XCTestCase {

    // MARK: - Helpers

    /// Reverse lookup: find the CGKeyCode for a given character.
    private func keyCode(for char: Character) -> CGKeyCode? {
        // Build a reverse map from the handler's public character(for:) method
        // by scanning the known range of key codes (0-47).
        let handler = DeactivationHandler(targetSequence: "")
        for code: CGKeyCode in 0...127 {
            if handler.character(for: code) == char {
                return code
            }
        }
        return nil
    }

    /// Feed a string of characters into the handler as keystrokes.
    private func feedString(_ string: String, into handler: DeactivationHandler) {
        for char in string {
            if let code = keyCode(for: char) {
                handler.feedKeystroke(code)
            }
        }
    }

    // MARK: - character(for:) mapping tests

    func testCharacterMappingForLetters() {
        let handler = DeactivationHandler(targetSequence: "")
        // Spot-check a few well-known macOS key codes
        XCTAssertEqual(handler.character(for: 0), "a")
        XCTAssertEqual(handler.character(for: 1), "s")
        XCTAssertEqual(handler.character(for: 13), "w")
        XCTAssertEqual(handler.character(for: 37), "l")
        XCTAssertEqual(handler.character(for: 45), "n")
        XCTAssertEqual(handler.character(for: 40), "k")
    }

    func testCharacterMappingForDigits() {
        let handler = DeactivationHandler(targetSequence: "")
        XCTAssertEqual(handler.character(for: 29), "0")
        XCTAssertEqual(handler.character(for: 18), "1")
        XCTAssertEqual(handler.character(for: 25), "9")
    }

    func testCharacterMappingReturnsNilForUnmappedCode() {
        let handler = DeactivationHandler(targetSequence: "")
        // Key code 36 is Return, not in our map
        XCTAssertNil(handler.character(for: 36))
        // Key code 100+ should be unmapped
        XCTAssertNil(handler.character(for: 100))
    }

    // MARK: - Sequence detection tests (Req 4.1, 4.3)

    func testCorrectSequenceTriggersDelegate() {
        let delegate = MockDeactivationDelegate()
        let handler = DeactivationHandler(targetSequence: "unlock")
        handler.delegate = delegate

        feedString("unlock", into: handler)

        XCTAssertEqual(delegate.completedCount, 1)
    }

    func testSequenceDetectionIsCaseSensitive() {
        let delegate = MockDeactivationDelegate()
        // Target is lowercase; our key map only produces lowercase
        let handler = DeactivationHandler(targetSequence: "abc")
        handler.delegate = delegate

        // Feed the correct characters (a=0, b=11, c=8)
        handler.feedKeystroke(0)   // a
        handler.feedKeystroke(11)  // b
        handler.feedKeystroke(8)   // c

        XCTAssertEqual(delegate.completedCount, 1)
    }

    func testDelegateNotCalledForPartialSequence() {
        let delegate = MockDeactivationDelegate()
        let handler = DeactivationHandler(targetSequence: "unlock")
        handler.delegate = delegate

        feedString("unlo", into: handler)

        XCTAssertEqual(delegate.completedCount, 0)
    }

    // MARK: - Buffer reset on mismatch (Req 4.5)

    func testIncorrectKeystrokeResetsBuffer() {
        let delegate = MockDeactivationDelegate()
        let handler = DeactivationHandler(targetSequence: "unlock")
        handler.delegate = delegate

        // Type "unx" — 'x' is wrong, should reset
        feedString("unx", into: handler)

        XCTAssertEqual(delegate.completedCount, 0)
        // Buffer should not contain "unx"
        XCTAssertNotEqual(handler.buffer, "unx")
    }

    func testSequenceCompletesAfterResetAndRetry() {
        let delegate = MockDeactivationDelegate()
        let handler = DeactivationHandler(targetSequence: "unlock")
        handler.delegate = delegate

        // Wrong attempt then correct
        feedString("unxunlock", into: handler)

        XCTAssertEqual(delegate.completedCount, 1)
    }

    // MARK: - Overlapping prefix handling

    func testOverlappingPrefixHandling() {
        // Target: "aab". If user types "a", "a", "b" — the first "a" starts,
        // second "a" mismatches position 1 (expected "a" at 1 — actually "aab"
        // so index 1 is "a"), let's use a clearer example.
        // Target: "aba". Type "a", "b", "a" → should match.
        let delegate = MockDeactivationDelegate()
        let handler = DeactivationHandler(targetSequence: "aba")
        handler.delegate = delegate

        feedString("aba", into: handler)
        XCTAssertEqual(delegate.completedCount, 1)
    }

    func testOverlappingPrefixWithFalseStart() {
        // Target: "aab". Type "a", "a", "a", "b" — the first two "a"s build
        // buffer "aa", then third "a" mismatches (expected "b"), but "a" is a
        // valid prefix start. Then "b" completes "ab" which is not "aab".
        // Actually: after "aa" + "a" → buffer becomes "a" (longest suffix of
        // "aaa" that is prefix of "aab" is "aa"). Then "b" → "aab" → match!
        let delegate = MockDeactivationDelegate()
        let handler = DeactivationHandler(targetSequence: "aab")
        handler.delegate = delegate

        feedString("aaab", into: handler)
        XCTAssertEqual(delegate.completedCount, 1)
    }

    // MARK: - Reset method

    func testResetClearsBuffer() {
        let handler = DeactivationHandler(targetSequence: "unlock")
        feedString("unl", into: handler)
        XCTAssertFalse(handler.buffer.isEmpty)

        handler.reset()
        XCTAssertTrue(handler.buffer.isEmpty)
    }

    // MARK: - Unmapped keystrokes are ignored

    func testUnmappedKeystrokeDoesNotAffectBuffer() {
        let handler = DeactivationHandler(targetSequence: "unlock")
        feedString("un", into: handler)
        let bufferBefore = handler.buffer

        // Feed an unmapped key code (e.g., Return = 36)
        handler.feedKeystroke(36)

        XCTAssertEqual(handler.buffer, bufferBefore)
    }

    // MARK: - Empty target sequence

    func testEmptyTargetSequenceNeverTriggers() {
        let delegate = MockDeactivationDelegate()
        let handler = DeactivationHandler(targetSequence: "")
        handler.delegate = delegate

        feedString("anything", into: handler)

        XCTAssertEqual(delegate.completedCount, 0)
    }

    // MARK: - Multiple completions

    func testSequenceCanBeCompletedMultipleTimes() {
        let delegate = MockDeactivationDelegate()
        let handler = DeactivationHandler(targetSequence: "ab")
        handler.delegate = delegate

        feedString("abab", into: handler)

        XCTAssertEqual(delegate.completedCount, 2)
    }

    // MARK: - Buffer resets after completion

    func testBufferResetsAfterCompletion() {
        let delegate = MockDeactivationDelegate()
        let handler = DeactivationHandler(targetSequence: "ab")
        handler.delegate = delegate

        feedString("ab", into: handler)

        XCTAssertEqual(delegate.completedCount, 1)
        XCTAssertTrue(handler.buffer.isEmpty)
    }
}
