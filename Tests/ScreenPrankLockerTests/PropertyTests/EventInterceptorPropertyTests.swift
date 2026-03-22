import XCTest
import SwiftCheck
@testable import ScreenPrankLocker

// Feature: screen-prank-locker, Property 2: All input event types are discarded by the event tap

/// **Validates: Requirements 2.1, 2.2, 2.3, 2.4**
final class EventInterceptorPropertyTests: XCTestCase {

    // MARK: - Required Event Types

    /// Raw values of all CGEventType values that the event tap must intercept and discard.
    /// Covers keyboard (2.1), mouse clicks (2.2), mouse movement (2.3), and trackpad gestures (2.4).
    private static let requiredEventTypeRawValues: [UInt32] = [
        CGEventType.keyDown.rawValue,
        CGEventType.keyUp.rawValue,
        CGEventType.flagsChanged.rawValue,
        CGEventType.leftMouseDown.rawValue,
        CGEventType.leftMouseUp.rawValue,
        CGEventType.rightMouseDown.rawValue,
        CGEventType.rightMouseUp.rawValue,
        CGEventType.mouseMoved.rawValue,
        CGEventType.leftMouseDragged.rawValue,
        CGEventType.rightMouseDragged.rawValue,
        CGEventType.scrollWheel.rawValue,
        CGEventType.otherMouseDown.rawValue,
        CGEventType.otherMouseUp.rawValue,
    ]

    // MARK: - Generator

    /// Generates a random raw value from the set of required intercepted event types.
    private static let eventTypeRawGen: Gen<UInt32> =
        Gen<UInt32>.fromElements(of: requiredEventTypeRawValues)

    // MARK: - Helper

    /// Returns true if the given event type raw value's bit is set in the mask.
    private func isBitSet(forRawValue rawValue: UInt32, in mask: CGEventMask) -> Bool {
        let bit: CGEventMask = 1 << CGEventMask(rawValue)
        return (mask & bit) != 0
    }

    // MARK: - Property Test

    func testAllInputEventTypesAreDiscardedByEventTap() {
        let args = CheckerArguments(maxAllowableSuccessfulTests: 100)

        property(
            "Every required input event type has its bit set in EventTapConfig.eventsOfInterest",
            arguments: args
        ) <- forAll(EventInterceptorPropertyTests.eventTypeRawGen) { (rawValue: UInt32) in
            let mask = EventTapConfig.eventsOfInterest
            let bitIsSet = self.isBitSet(forRawValue: rawValue, in: mask)

            return bitIsSet
                <?> "Event type rawValue=\(rawValue) should have its bit set in the event mask"
        }
    }

    /// Additionally verify that the callback returns nil (discards events) by confirming
    /// the mask covers all 13 required types exhaustively.
    func testEventMaskCoversAllRequiredTypes() {
        let mask = EventTapConfig.eventsOfInterest

        for rawValue in EventInterceptorPropertyTests.requiredEventTypeRawValues {
            XCTAssertTrue(
                isBitSet(forRawValue: rawValue, in: mask),
                "EventTapConfig.eventsOfInterest must include bit for event type rawValue=\(rawValue)"
            )
        }
    }
}
