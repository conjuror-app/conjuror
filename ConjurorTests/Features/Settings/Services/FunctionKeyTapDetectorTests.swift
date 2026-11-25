import AppKit
import Testing

@testable import Conjuror

@Suite("Function Key Tap Detector")
struct FunctionKeyTapDetectorTests {
  private enum Step {
    case flags(NSEvent.ModifierFlags, at: TimeInterval)
    case keyDown
  }

  /// Returns the times at which a tap was recognised.
  private static func taps(_ steps: [Step]) -> [TimeInterval] {
    var detector = FunctionKeyTapDetector()
    var taps = [TimeInterval]()

    for step in steps {
      switch step {
      case let .flags(flags, timestamp):
        if detector.handleModifierChange(flags, at: timestamp) {
          taps.append(timestamp)
        }
      case .keyDown:
        detector.handleKeyDown()
      }
    }

    return taps
  }

  @Test("A quick press and release of fn on its own is a tap")
  func testTap() {
    #expect(Self.taps([.flags(.function, at: 1), .flags([], at: 1.2)]) == [1.2])
  }

  @Test("Holding fn too long is not a tap")
  func testHeldTooLong() {
    #expect(Self.taps([.flags(.function, at: 1), .flags([], at: 1.6)]).isEmpty)
  }

  @Test("Pressing a key while fn is held is not a tap")
  func testKeyPressedWhileHeld() {
    #expect(Self.taps([.flags(.function, at: 1), .keyDown, .flags([], at: 1.1)]).isEmpty)
  }

  @Test("Using another modifier with fn is not a tap")
  func testOtherModifiers() {
    let pressedAfter = Self.taps([
      .flags(.function, at: 1),
      .flags([.function, .command], at: 1.05),
      .flags(.function, at: 1.1),
      .flags([], at: 1.15),
    ])
    let pressedBefore = Self.taps([
      .flags(.shift, at: 1),
      .flags([.shift, .function], at: 1.05),
      .flags(.shift, at: 1.1),
    ])

    #expect(pressedAfter.isEmpty)
    #expect(pressedBefore.isEmpty)
  }

  @Test("A cancelled press does not block the next tap")
  func testTapAfterCancelledPress() {
    let taps = Self.taps([
      .flags(.function, at: 1),
      .keyDown,
      .flags([], at: 1.1),
      .flags(.function, at: 2),
      .flags([], at: 2.1),
    ])

    #expect(taps == [2.1])
  }
}
