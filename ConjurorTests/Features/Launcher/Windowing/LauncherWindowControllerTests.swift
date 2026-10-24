import AppKit
import Carbon.HIToolbox
import SwiftUI
import Testing

@testable import Conjuror

@Suite("Launcher Window Controller")
struct LauncherWindowControllerTests {
  @Test("Collapsed and expanded heights", arguments: LauncherAppearance.allCases)
  func testAppearanceHeights(appearance: LauncherAppearance) {
    let layout = LauncherLayout(appearance: appearance)
    let expanded = layout.expandedHeight(
      resultCount: 5,
      hasCatalogError: false,
      hasHotKeyError: false,
      hasLaunchError: false,
      maximumVisibleResults: 7
    )

    #expect(layout.collapsedHeight == (appearance == .standard ? 54 : 46))
    #expect(expanded == (appearance == .standard ? 294 : 217))
  }

  @Test(
    "Results beyond the visible limit do not grow the panel",
    arguments: LauncherAppearance.allCases
  )
  func testHeightCapsVisibleResults(appearance: LauncherAppearance) {
    let layout = LauncherLayout(appearance: appearance)

    for resultCount in [3, 4, 100] {
      let height = layout.expandedHeight(
        resultCount: resultCount,
        hasCatalogError: false,
        hasHotKeyError: false,
        hasLaunchError: false,
        maximumVisibleResults: 3
      )
      #expect(height == (appearance == .standard ? 212 : 151))
    }
  }

  @Test(
    "Empty states and errors reserve space in both appearances",
    arguments: LauncherAppearance.allCases
  )
  func testEmptyAndErrorHeights(appearance: LauncherAppearance) {
    let layout = LauncherLayout(appearance: appearance)
    let empty = layout.expandedHeight(
      resultCount: 0,
      hasCatalogError: false,
      hasHotKeyError: false,
      hasLaunchError: false,
      maximumVisibleResults: 7
    )
    let catalogError = layout.expandedHeight(
      resultCount: 5,
      hasCatalogError: true,
      hasHotKeyError: false,
      hasLaunchError: false,
      maximumVisibleResults: 7
    )
    let actionAndHotKeyErrors = layout.expandedHeight(
      resultCount: 5,
      hasCatalogError: false,
      hasHotKeyError: true,
      hasLaunchError: true,
      maximumVisibleResults: 7
    )

    #expect(empty == (appearance == .standard ? 125 : 117))
    #expect(catalogError == (appearance == .standard ? 157 : 149))
    #expect(actionAndHotKeyErrors == (appearance == .standard ? 346 : 269))
  }

  @MainActor
  @Test("Height changes resize after the current update")
  func testDeferredResize() async throws {
    let controller = makeController()
    defer { controller.hide() }
    let window = try #require(controller.window)
    let hostingController = try #require(
      window.contentViewController as? NSHostingController<LauncherView>
    )
    // Allow test heights without SwiftUI constraining the window.
    hostingController.sizingOptions = []
    let initialFrame = window.frame

    hostingController.rootView.onHeightChange(140)
    hostingController.rootView.onHeightChange(180)

    #expect(window.frame == initialFrame)
    await finishPendingWindowUpdates()
    #expect(window.frame.size == LauncherLayout.windowSize(contentHeight: 180))
  }

  @MainActor
  @Test("Hiding releases content without animation or queued resizing")
  func testHideDiscardsPendingResizes() async throws {
    let controller = makeController()
    defer { controller.hide() }
    let window = try #require(controller.window)
    let hostingController = try #require(
      window.contentViewController as? NSHostingController<LauncherView>
    )
    // Avoid taking focus from the launcher keyboard tests.
    window.orderBack(nil)
    #expect(window.isVisible)
    let initialFrame = window.frame

    hostingController.rootView.onHeightChange(180)
    controller.hide()
    // A callback from the old view must also be harmless after teardown.
    hostingController.rootView.onHeightChange(240)

    #expect(window.animationBehavior == .none)
    #expect(!window.isVisible)
    #expect(window.contentViewController == nil)
    await finishPendingWindowUpdates()
    #expect(window.frame == initialFrame)
    #expect(!window.isVisible)
  }

  @Test("Centered frames use visible-frame coordinates")
  func testCenteredFrame() {
    let visibleFrame = NSRect(x: 1_000, y: 50, width: 800, height: 600)

    let frame = LauncherWindowGeometry.centeredFrame(
      size: NSSize(width: 540, height: 54),
      visibleFrame: visibleFrame
    )

    #expect(frame.origin.x == 1_130)
    #expect(frame.origin.y == 473)
  }

  @Test("Resized frames keep the top edge and stay visible")
  func testResizeKeepsTopEdge() {
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

  @Test("Window frames are constrained to small visible frames")
  func testSmallScreen() {
    let visibleFrame = NSRect(x: 100, y: 200, width: 400, height: 300)

    let frame = LauncherWindowGeometry.centeredFrame(
      size: NSSize(width: 540, height: 500),
      visibleFrame: visibleFrame
    )

    #expect(frame == visibleFrame)
  }

  @Test(
    "Emoji rows, recent header, and scrolling limit",
    arguments: LauncherAppearance.allCases
  )
  func testEmojiHeights(appearance: LauncherAppearance) {
    let layout = LauncherLayout(appearance: appearance)

    for itemCount in [1, 9] {
      let height = layout.emojiExpandedHeight(
        itemCount: itemCount,
        hasRecentHeader: false,
        hasHotKeyError: false,
        maximumVisibleResults: 3
      )
      #expect(height == (appearance == .standard ? 132 : 89))
    }

    let twoRows = layout.emojiExpandedHeight(
      itemCount: 10,
      hasRecentHeader: false,
      hasHotKeyError: false,
      maximumVisibleResults: 3
    )
    #expect(twoRows == (appearance == .standard ? 176 : 127))

    for itemCount in [27, 28, 100] {
      let height = layout.emojiExpandedHeight(
        itemCount: itemCount,
        hasRecentHeader: true,
        hasHotKeyError: false,
        maximumVisibleResults: 3
      )
      #expect(height == (appearance == .standard ? 237 : 182))
    }
  }

  @Test("Command shortcuts ignore Caps Lock and reject other modifiers")
  func testCommandModifiers() {
    #expect(LauncherKeyboardNavigation.relevantModifiers([.command, .capsLock]) == .command)
    #expect(LauncherKeyboardNavigation.relevantModifiers([.command, .option]) != .command)
  }

  @Test("Horizontal navigation requires opt-in")
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

  @Test("Keyboard navigation ignores modified arrows and marked text")
  func testArrowModifiersAndMarkedText() {
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

  @Test("Text-editing commands recognize standard shortcuts")
  func testEditingShortcuts() {
    #expect(command("a") == .selectAll)
    #expect(command("c") == .copy)
    #expect(command("v") == .paste)
    #expect(command("x") == .cut)
    #expect(command("z") == .undo)
    #expect(command("Z", modifiers: [.command, .shift]) == .redo)
  }

  @Test("Text-editing commands ignore unsupported modifiers and keys")
  func testUnsupportedEditingShortcuts() {
    #expect(command("a", modifiers: .option) == nil)
    #expect(command("b") == nil)
    #expect(command(nil) == nil)
  }

  @MainActor
  @Test("The panel routes unmodified Tab to mode cycling")
  func testTabCyclesMode() {
    let panel = makePanel()
    defer { panel.close() }
    var cycleCount = 0
    panel.onCycleMode = { cycleCount += 1 }

    panel.sendEvent(keyEvent("\t", keyCode: UInt16(kVK_Tab)))
    panel.sendEvent(keyEvent("\t", keyCode: UInt16(kVK_Tab), modifiers: .control))

    #expect(cycleCount == 1)
  }

  @MainActor
  @Test("The panel preserves arrow-key navigation")
  func testPanelPreservesArrowKeyNavigation() {
    let panel = makePanel()
    defer { panel.close() }
    var directions: [MoveCommandDirection] = []
    panel.onMoveSelection = { directions.append($0) }

    panel.sendEvent(keyEvent("", keyCode: UInt16(kVK_DownArrow)))

    #expect(directions == [.down])
  }

  @MainActor
  @Test(
    "The panel gives Command-Q precedence over the text-editing responder"
  )
  func testCommandQPrecedence() {
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
  @Test(
    "The panel routes text-editing shortcuts to the active text view"
  )
  func testEditingResponder() {
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
    "The panel does not consume text-editing shortcuts outside a text editor"
  )
  func testNoEditingResponder() {
    let panel = makePanel()
    defer { panel.close() }
    panel.contentView?.addSubview(NSButton())

    #expect(!panel.performKeyEquivalent(with: keyEvent("c", modifiers: .command)))
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
  private func makeController() -> LauncherWindowController {
    let settings = SettingsStore(userDefaults: makeTestUserDefaults())
    let hotKeys = HotKeyStore(settingsStore: settings, onHotKeyPressed: { _ in })

    return LauncherWindowController(
      store: LauncherStore(settingsStore: settings),
      settingsStore: settings,
      hotKeyStore: hotKeys,
      onHide: {},
      onOpenSettings: {}
    )
  }

  @MainActor
  private func finishPendingWindowUpdates() async {
    await withCheckedContinuation { continuation in
      DispatchQueue.main.async {
        continuation.resume()
      }
    }
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
