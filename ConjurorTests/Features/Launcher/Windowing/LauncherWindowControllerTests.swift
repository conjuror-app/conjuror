import AppKit
import Carbon.HIToolbox
import XCTest

@testable import Conjuror

final class LauncherWindowControllerTests: XCTestCase {
  func testCenteredFrameUsesVisibleFrameCoordinates() {
    let visibleFrame = NSRect(x: 1_000, y: 50, width: 800, height: 600)

    let frame = LauncherWindowGeometry.centeredFrame(
      size: NSSize(width: 540, height: 54),
      visibleFrame: visibleFrame
    )

    XCTAssertEqual(frame.origin.x, 1_130)
    XCTAssertEqual(frame.origin.y, 413)
  }

  func testResizedFrameKeepsTopEdgeAndStaysVisible() {
    let visibleFrame = NSRect(x: 0, y: 40, width: 1_000, height: 600)
    let currentFrame = NSRect(x: 230, y: 400, width: 540, height: 54)

    let frame = LauncherWindowGeometry.resizedFrame(
      currentFrame: currentFrame,
      targetSize: NSSize(width: 540, height: 400),
      visibleFrame: visibleFrame
    )

    XCTAssertEqual(frame.maxY, currentFrame.maxY)
    XCTAssertGreaterThanOrEqual(frame.minY, visibleFrame.minY)
  }

  func testWindowFrameIsConstrainedToSmallVisibleFrame() {
    let visibleFrame = NSRect(x: 100, y: 200, width: 400, height: 300)

    let frame = LauncherWindowGeometry.centeredFrame(
      size: NSSize(width: 540, height: 500),
      visibleFrame: visibleFrame
    )

    XCTAssertEqual(frame, visibleFrame)
  }

  func testKeyboardNavigationIgnoresModifiedArrowsAndMarkedText() {
    XCTAssertNil(
      LauncherKeyboardNavigation.direction(
        forKeyCode: UInt16(kVK_UpArrow),
        modifiers: .option,
        hasMarkedText: false
      )
    )
    XCTAssertNil(
      LauncherKeyboardNavigation.direction(
        forKeyCode: UInt16(kVK_DownArrow),
        modifiers: [],
        hasMarkedText: true
      )
    )
    XCTAssertNotNil(
      LauncherKeyboardNavigation.direction(
        forKeyCode: UInt16(kVK_DownArrow),
        modifiers: .numericPad,
        hasMarkedText: false
      )
    )
  }
}
