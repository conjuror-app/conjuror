import AppKit
import Carbon.HIToolbox
import SwiftUI
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

  func testEmojiHeightCountsGridRowsAndRecentHeader() {
    let oneItemHeight = emojiHeight(itemCount: 1)
    let nineItemHeight = emojiHeight(itemCount: 9)
    let tenItemHeight = emojiHeight(itemCount: 10)

    XCTAssertEqual(oneItemHeight, nineItemHeight)
    XCTAssertEqual(
      tenItemHeight - nineItemHeight,
      LauncherLayout.emojiRowHeight + LauncherLayout.emojiRowSpacing
    )
    XCTAssertEqual(
      emojiHeight(itemCount: 9, hasRecentHeader: true) - nineItemHeight,
      LauncherLayout.emojiRecentHeaderHeight + 1
    )
  }

  func testCommandShortcutsIgnoreCapsLockAndRejectOtherModifiers() {
    XCTAssertTrue(
      LauncherKeyboardNavigation.hasOnlyCommandModifier([.command, .capsLock])
    )
    XCTAssertFalse(
      LauncherKeyboardNavigation.hasOnlyCommandModifier([.command, .option])
    )
  }

  func testHorizontalNavigationRequiresOptIn() {
    XCTAssertNil(
      LauncherKeyboardNavigation.direction(
        forKeyCode: UInt16(kVK_LeftArrow),
        modifiers: [],
        hasMarkedText: false
      )
    )
    XCTAssertEqual(
      LauncherKeyboardNavigation.direction(
        forKeyCode: UInt16(kVK_RightArrow),
        modifiers: [],
        hasMarkedText: false,
        allowsHorizontalNavigation: true
      ),
      .right
    )
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

  func testTextEditingCommandRecognizesStandardShortcuts() {
    XCTAssertEqual(command("a"), .selectAll)
    XCTAssertEqual(command("c"), .copy)
    XCTAssertEqual(command("v"), .paste)
    XCTAssertEqual(command("x"), .cut)
    XCTAssertEqual(command("z"), .undo)
    XCTAssertEqual(command("Z", modifiers: [.command, .shift]), .redo)
  }

  func testTextEditingCommandIgnoresUnsupportedModifiersAndKeys() {
    XCTAssertNil(command("a", modifiers: .option))
    XCTAssertNil(command("b"))
    XCTAssertNil(command(nil))
  }

  @MainActor
  func testPanelRoutesTextEditingShortcutsToActiveTextView() {
    let panel = makePanel()
    let textView = RecordingTextView()
    panel.contentView?.addSubview(textView)
    XCTAssertTrue(panel.makeFirstResponder(textView))

    for (key, expectedAction) in [
      ("a", "selectAll"),
      ("c", "copy"),
      ("v", "paste"),
      ("x", "cut"),
      ("z", "undo"),
      ("Z", "redo"),
    ] {
      let modifiers: NSEvent.ModifierFlags = key == "Z" ? [.command, .shift] : .command

      XCTAssertTrue(panel.performKeyEquivalent(with: keyEvent(key, modifiers: modifiers)))
      XCTAssertEqual(textView.actions.last, expectedAction)
    }
  }

  @MainActor
  func testPanelDoesNotConsumeTextEditingShortcutOutsideTextEditor() {
    let panel = makePanel()
    panel.contentView?.addSubview(NSButton())

    XCTAssertFalse(panel.performKeyEquivalent(with: keyEvent("c", modifiers: .command)))
  }

  @MainActor
  func testPanelGivesCommandQPrecedenceOverTextEditingResponder() {
    let panel = makePanel()
    let textView = RecordingTextView()
    var terminateCount = 0
    panel.onTerminate = { terminateCount += 1 }
    panel.contentView?.addSubview(textView)
    XCTAssertTrue(panel.makeFirstResponder(textView))

    XCTAssertTrue(panel.performKeyEquivalent(with: keyEvent("q", modifiers: .command)))
    XCTAssertEqual(terminateCount, 1)
    XCTAssertTrue(textView.actions.isEmpty)
  }

  @MainActor
  func testPanelPreservesArrowKeyNavigation() {
    let panel = makePanel()
    var directions: [MoveCommandDirection] = []
    panel.onMoveSelection = { directions.append($0) }

    panel.sendEvent(keyEvent("", keyCode: UInt16(kVK_DownArrow)))

    XCTAssertEqual(directions, [.down])
  }

  @MainActor
  func testPanelRoutesUnmodifiedTabToModeCycling() {
    let panel = makePanel()
    var cycleCount = 0
    panel.onCycleMode = { cycleCount += 1 }

    panel.sendEvent(keyEvent("\t", keyCode: UInt16(kVK_Tab)))
    panel.sendEvent(keyEvent("\t", keyCode: UInt16(kVK_Tab), modifiers: .control))

    XCTAssertEqual(cycleCount, 1)
  }

  private func command(
    _ characters: String?,
    modifiers: NSEvent.ModifierFlags = .command
  ) -> LauncherTextEditingCommand? {
    LauncherTextEditingCommand.command(
      charactersIgnoringModifiers: characters,
      modifiers: modifiers
    )
  }

  @MainActor
  private func makePanel() -> LauncherPanel {
    let panel = LauncherPanel(
      contentRect: NSRect(x: 0, y: 0, width: 200, height: 100),
      styleMask: [.borderless, .nonactivatingPanel],
      backing: .buffered,
      defer: false
    )
    panel.contentView = NSView(frame: panel.contentView?.bounds ?? .zero)
    panel.makeKeyAndOrderFront(nil)
    addTeardownBlock {
      panel.close()
    }
    return panel
  }

  @MainActor
  private func keyEvent(
    _ characters: String,
    keyCode: UInt16 = 0,
    modifiers: NSEvent.ModifierFlags = []
  ) -> NSEvent {
    NSEvent.keyEvent(
      with: .keyDown,
      location: .zero,
      modifierFlags: modifiers,
      timestamp: 0,
      windowNumber: 0,
      context: nil,
      characters: characters,
      charactersIgnoringModifiers: characters,
      isARepeat: false,
      keyCode: keyCode
    )!
  }

  private func emojiHeight(itemCount: Int, hasRecentHeader: Bool = false) -> CGFloat {
    LauncherLayout.emojiExpandedHeight(
      itemCount: itemCount,
      hasRecentHeader: hasRecentHeader,
      hasHotKeyError: false,
      maximumVisibleResults: SettingsStore.defaultMaximumVisibleResults
    )
  }
}

private final class RecordingTextView: NSTextView {
  var actions: [String] = []

  override func copy(_ sender: Any?) { actions.append("copy") }
  override func cut(_ sender: Any?) { actions.append("cut") }
  override func paste(_ sender: Any?) { actions.append("paste") }
  override func selectAll(_ sender: Any?) { actions.append("selectAll") }
  @objc func undo(_ sender: Any?) { actions.append("undo") }
  @objc func redo(_ sender: Any?) { actions.append("redo") }
}
