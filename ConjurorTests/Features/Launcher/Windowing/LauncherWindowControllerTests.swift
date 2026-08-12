import AppKit
import Carbon.HIToolbox
import SwiftUI
import Testing

@testable import Conjuror

@Suite("Launcher Window Controller")
struct LauncherWindowControllerTests {
  @Test("Launcher window controller: centered frames use visible-frame coordinates")
  func testCenteredFrameUsesVisibleFrameCoordinates() {
    let visibleFrame = NSRect(x: 1_000, y: 50, width: 800, height: 600)

    let frame = LauncherWindowGeometry.centeredFrame(
      size: NSSize(width: 540, height: 54),
      visibleFrame: visibleFrame
    )

    #expect(frame.origin.x == 1_130)
    #expect(frame.origin.y == 413)
  }

  @Test("Launcher window controller: resized frames keep the top edge and stay visible")
  func testResizedFrameKeepsTopEdgeAndStaysVisible() {
    let visibleFrame = NSRect(x: 0, y: 40, width: 1_000, height: 600)
    let currentFrame = NSRect(x: 230, y: 400, width: 540, height: 54)

    let frame = LauncherWindowGeometry.resizedFrame(
      currentFrame: currentFrame,
      targetSize: NSSize(width: 540, height: 400),
      visibleFrame: visibleFrame
    )

    #expect(frame.maxY == currentFrame.maxY)
    #expect(frame.minY >= visibleFrame.minY)
  }

  @Test("Launcher window controller: window frames are constrained to small visible frames")
  func testWindowFrameIsConstrainedToSmallVisibleFrame() {
    let visibleFrame = NSRect(x: 100, y: 200, width: 400, height: 300)

    let frame = LauncherWindowGeometry.centeredFrame(
      size: NSSize(width: 540, height: 500),
      visibleFrame: visibleFrame
    )

    #expect(frame == visibleFrame)
  }

  @MainActor
  @Test("Launcher window controller: emoji height counts grid rows and the recent header")
  func testEmojiHeightCountsGridRowsAndRecentHeader() {
    let oneItemHeight = emojiHeight(itemCount: 1)
    let nineItemHeight = emojiHeight(itemCount: 9)
    let tenItemHeight = emojiHeight(itemCount: 10)

    #expect(oneItemHeight == nineItemHeight)
    #expect(
      tenItemHeight - nineItemHeight == LauncherLayout.emojiRowHeight
        + LauncherLayout.emojiRowSpacing
    )
    #expect(
      emojiHeight(itemCount: 9, hasRecentHeader: true) - nineItemHeight == LauncherLayout
        .emojiRecentHeaderHeight + 1
    )
  }

  @Test("Launcher window controller: command shortcuts ignore Caps Lock and reject other modifiers")
  func testCommandShortcutsIgnoreCapsLockAndRejectOtherModifiers() {
    #expect(LauncherKeyboardNavigation.hasOnlyCommandModifier([.command, .capsLock]))
    #expect(!(LauncherKeyboardNavigation.hasOnlyCommandModifier([.command, .option])))
  }

  @Test("Launcher window controller: horizontal navigation requires opt-in")
  func testHorizontalNavigationRequiresOptIn() {
    #expect(
      (LauncherKeyboardNavigation.direction(
        forKeyCode: UInt16(kVK_LeftArrow),
        modifiers: [],
        hasMarkedText: false
      )) == nil
    )
    #expect(
      LauncherKeyboardNavigation.direction(
        forKeyCode: UInt16(kVK_RightArrow),
        modifiers: [],
        hasMarkedText: false,
        allowsHorizontalNavigation: true
      ) == .right
    )
  }

  @Test("Launcher window controller: keyboard navigation ignores modified arrows and marked text")
  func testKeyboardNavigationIgnoresModifiedArrowsAndMarkedText() {
    #expect(
      (LauncherKeyboardNavigation.direction(
        forKeyCode: UInt16(kVK_UpArrow),
        modifiers: .option,
        hasMarkedText: false
      )) == nil
    )
    #expect(
      (LauncherKeyboardNavigation.direction(
        forKeyCode: UInt16(kVK_DownArrow),
        modifiers: [],
        hasMarkedText: true
      )) == nil
    )
    #expect(
      (LauncherKeyboardNavigation.direction(
        forKeyCode: UInt16(kVK_DownArrow),
        modifiers: .numericPad,
        hasMarkedText: false
      )) != nil
    )
  }

  @Test("Launcher window controller: text-editing commands recognize standard shortcuts")
  func testTextEditingCommandRecognizesStandardShortcuts() {
    #expect(command("a") == .selectAll)
    #expect(command("c") == .copy)
    #expect(command("v") == .paste)
    #expect(command("x") == .cut)
    #expect(command("z") == .undo)
    #expect(command("Z", modifiers: [.command, .shift]) == .redo)
  }

  @Test("Launcher window controller: text-editing commands ignore unsupported modifiers and keys")
  func testTextEditingCommandIgnoresUnsupportedModifiersAndKeys() {
    #expect((command("a", modifiers: .option)) == nil)
    #expect((command("b")) == nil)
    #expect((command(nil)) == nil)
  }

  @MainActor
  @Test(
    "Launcher window controller: the panel routes text-editing shortcuts to the active text view"
  )
  func testPanelRoutesTextEditingShortcutsToActiveTextView() {
    let panel = makePanel()
    defer { panel.close() }
    let textView = RecordingTextView()
    panel.contentView?.addSubview(textView)
    #expect(panel.makeFirstResponder(textView))

    for (key, expectedAction) in [
      ("a", "selectAll"),
      ("c", "copy"),
      ("v", "paste"),
      ("x", "cut"),
      ("z", "undo"),
      ("Z", "redo"),
    ] {
      let modifiers: NSEvent.ModifierFlags = key == "Z" ? [.command, .shift] : .command

      #expect(panel.performKeyEquivalent(with: keyEvent(key, modifiers: modifiers)))
      #expect(textView.actions.last == expectedAction)
    }
  }

  @MainActor
  @Test(
    "Launcher window controller: the panel does not consume text-editing shortcuts outside a text editor"
  )
  func testPanelDoesNotConsumeTextEditingShortcutOutsideTextEditor() {
    let panel = makePanel()
    defer { panel.close() }
    panel.contentView?.addSubview(NSButton())

    #expect(!(panel.performKeyEquivalent(with: keyEvent("c", modifiers: .command))))
  }

  @MainActor
  @Test(
    "Launcher window controller: the panel gives Command-Q precedence over the text-editing responder"
  )
  func testPanelGivesCommandQPrecedenceOverTextEditingResponder() {
    let panel = makePanel()
    defer { panel.close() }
    let textView = RecordingTextView()
    var terminateCount = 0
    panel.onTerminate = { terminateCount += 1 }
    panel.contentView?.addSubview(textView)
    #expect(panel.makeFirstResponder(textView))

    #expect(panel.performKeyEquivalent(with: keyEvent("q", modifiers: .command)))
    #expect(terminateCount == 1)
    #expect(textView.actions.isEmpty)
  }

  @MainActor
  @Test("Launcher window controller: the panel preserves arrow-key navigation")
  func testPanelPreservesArrowKeyNavigation() {
    let panel = makePanel()
    defer { panel.close() }
    var directions: [MoveCommandDirection] = []
    panel.onMoveSelection = { directions.append($0) }

    panel.sendEvent(keyEvent("", keyCode: UInt16(kVK_DownArrow)))

    #expect(directions == [.down])
  }

  @MainActor
  @Test("Launcher window controller: the panel routes unmodified Tab to mode cycling")
  func testPanelRoutesUnmodifiedTabToModeCycling() {
    let panel = makePanel()
    defer { panel.close() }
    var cycleCount = 0
    panel.onCycleMode = { cycleCount += 1 }

    panel.sendEvent(keyEvent("\t", keyCode: UInt16(kVK_Tab)))
    panel.sendEvent(keyEvent("\t", keyCode: UInt16(kVK_Tab), modifiers: .control))

    #expect(cycleCount == 1)
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

  @MainActor
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
