import Testing

@testable import Conjuror

@MainActor
extension LauncherStoreTests {
  @Test("Hash switches to clipboard history only when it's turned on")
  func testClipboardPrefix() {
    let settings = SettingsStore(userDefaults: makeTestUserDefaults())
    let store = makeStore(settingsStore: settings)

    store.updateQuery("#")
    #expect(store.mode == .applications)

    settings.setClipboardHistoryEnabled(true)
    store.updateQuery("")
    store.updateQuery("#")
    #expect(store.mode == .clipboard)
  }

  @Test("Clipboard search matches every word and keeps the newest first")
  func testClipboardSearch() {
    let history = ClipboardHistoryStore(fileURL: nil)
    history.record("git push origin main", source: nil)
    history.record("Café opening hours", source: nil)
    history.record("git pull origin main", source: nil)
    let store = makeClipboardStore(history: history)

    store.updateQuery("#origin GIT")
    #expect(
      store.filteredClipboardItems.map(\.text) == ["git pull origin main", "git push origin main"]
    )

    store.query = "cafe"
    #expect(store.filteredClipboardItems.map(\.text) == ["Café opening hours"])
  }

  @Test("New copies appear while clipboard history is open")
  func testClipboardUpdatesLive() {
    let history = ClipboardHistoryStore(fileURL: nil)
    let store = makeClipboardStore(history: history)
    store.updateQuery("#")

    history.record("fresh", source: nil)

    #expect(store.filteredClipboardItems.map(\.text) == ["fresh"])
    #expect(
      store.selectedResultID == store.filteredClipboardItems.first.map { .clipboardItem($0.id) }
    )
  }

  @Test("Return pastes the selected item and moves it to the top")
  func testPasteClipboardItem() {
    let history = ClipboardHistoryStore(fileURL: nil)
    history.record("older", source: nil)
    history.record("newer", source: nil)
    let clipboard = RecordingClipboard()
    let paster = ClipboardPasterStub()
    var events = [LauncherEvent]()
    let store = makeClipboardStore(
      history: history,
      writeToClipboard: clipboard.write,
      paster: paster,
      onEvent: { events.append($0) }
    )
    store.updateQuery("#")
    store.moveSelection(.down)

    store.openSelectedResult()

    #expect(clipboard.text == "older")
    #expect(paster.pasteCount == 1)
    #expect(events == [.clipboardItemPasted])
    #expect(history.items.first?.text == "older")
    #expect(store.mode == .applications)
  }

  @Test("Return only copies when Conjuror can't send keystrokes")
  func testCopyWithoutAccessibility() {
    let history = ClipboardHistoryStore(fileURL: nil)
    history.record("text", source: nil)
    let clipboard = RecordingClipboard()
    let paster = ClipboardPasterStub(canPaste: false)
    var events = [LauncherEvent]()
    let store = makeClipboardStore(
      history: history,
      writeToClipboard: clipboard.write,
      paster: paster,
      onEvent: { events.append($0) }
    )
    store.updateQuery("#")

    store.openSelectedResult()

    #expect(clipboard.text == "text")
    #expect(paster.pasteCount == 0)
    #expect(events == [.clipboardItemCopied])
  }

  @Test("Command-Return copies without pasting")
  func testCommandReturnCopies() {
    let history = ClipboardHistoryStore(fileURL: nil)
    history.record("text", source: nil)
    let clipboard = RecordingClipboard()
    let paster = ClipboardPasterStub()
    let store = makeClipboardStore(
      history: history,
      writeToClipboard: clipboard.write,
      paster: paster
    )
    store.updateQuery("#")

    store.revealSelectedResult()

    #expect(clipboard.text == "text")
    #expect(paster.pasteCount == 0)
  }

  @Test("Deleting an item selects the one after it")
  func testDeleteClipboardItem() {
    let history = ClipboardHistoryStore(fileURL: nil)
    for text in ["third", "second", "first"] { history.record(text, source: nil) }
    let store = makeClipboardStore(history: history)
    store.updateQuery("#")
    store.moveSelection(.down)

    store.deleteSelectedClipboardItem()

    #expect(history.items.map(\.text) == ["first", "third"])
    #expect(store.selectedResultID == .clipboardItem(history.items[1].id))
  }

  @Test("Turning clipboard history off leaves its mode")
  func testDisablingLeavesClipboardMode() {
    let settings = SettingsStore(userDefaults: makeTestUserDefaults())
    settings.setClipboardHistoryEnabled(true)
    let store = makeStore(settingsStore: settings)
    store.updateQuery("#")

    settings.setClipboardHistoryEnabled(false)

    #expect(store.mode == .applications)
  }

  private func makeClipboardStore(
    history: ClipboardHistoryStore,
    writeToClipboard: @escaping @MainActor (String) -> Void = { _ in },
    paster: ClipboardPasterStub = ClipboardPasterStub(),
    onEvent: @escaping (LauncherEvent) -> Void = { _ in }
  ) -> LauncherStore {
    let settings = SettingsStore(userDefaults: makeTestUserDefaults())
    settings.setClipboardHistoryEnabled(true)

    return makeStore(
      settingsStore: settings,
      writeToClipboard: writeToClipboard,
      clipboardHistory: history,
      clipboardPaster: paster,
      onEvent: onEvent
    )
  }
}

@MainActor
final class ClipboardPasterStub: ClipboardPasting {
  let canPaste: Bool
  private(set) var pasteCount = 0

  init(canPaste: Bool = true) {
    self.canPaste = canPaste
  }

  func paste() {
    pasteCount += 1
  }
}
