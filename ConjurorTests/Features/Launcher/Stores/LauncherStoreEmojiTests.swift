import AppKit
import Testing

@testable import Conjuror

@MainActor
extension LauncherStoreTests {
  @Test("Preferred skin tone replaces tone-capable base emoji")
  func testPreferredSkinTone() {
    let settings = SettingsStore(userDefaults: makeTestUserDefaults())
    settings.setPreferredEmojiSkinTone(.mediumDark)
    let store = makeStore(settingsStore: settings)

    store.updateQuery(":waving hand")

    #expect(store.displayedEmoji.first?.value == "👋🏾")
    #expect(!store.displayedEmoji.contains { $0.value == "👋" })
  }

  @Test("Preferred skin tone replaces gendered couple emoji")
  func testCoupleSkinTone() {
    let settings = SettingsStore(userDefaults: makeTestUserDefaults())
    settings.setPreferredEmojiSkinTone(.mediumDark)
    let store = makeStore(settingsStore: settings)

    store.updateQuery(":kiss woman man")

    #expect(store.displayedEmoji.first?.value == "👩🏾‍❤️‍💋‍👨🏾")
    #expect(!store.displayedEmoji.contains { $0.value == "👩‍❤️‍💋‍👨" })
  }

  @Test("Colon switches to emoji and filters following text")
  func testEmojiPrefix() {
    let store = makeStore()

    store.updateQuery(":waving hand medium dark")

    #expect(store.mode == .emoji)
    #expect(store.query == "waving hand medium dark")
    #expect(store.filteredEmoji.first?.value == "👋🏾")
  }

  @Test("Horizontal arrows navigate the emoji grid")
  func testHorizontalArrowsNavigateEmojiGrid() {
    let store = makeStore()
    store.updateQuery(":")
    let firstID = store.selectedResultID

    store.moveSelection(.right)
    #expect(store.selectedResultID == .emoji(store.displayedEmoji[1].id))

    store.moveSelection(.left)
    #expect(store.selectedResultID == firstID)
  }

  @Test("Launcher store: Return pastes emoji and records it as recent")
  func testPasteEmoji() {
    let clipboard = RecordingClipboard()
    let history = EmojiHistoryStore(userDefaults: makeTestUserDefaults())
    let paster = ClipboardPasterStub()
    var events = [LauncherEvent]()
    let store = makeStore(
      writeToClipboard: clipboard.write,
      emojiHistory: history,
      clipboardPaster: paster,
      onEvent: { events.append($0) }
    )
    store.updateQuery(":face with tears of joy")

    store.openSelectedResult()

    #expect(clipboard.text == "😂")
    #expect(paster.pasteCount == 1)
    #expect(events == [.emojiPasted])
    #expect(history.load().first == "😂")
    #expect(store.mode == .applications)
    #expect(store.selectedResultID == nil)
  }

  @Test("Launcher store: Return only copies emoji when Conjuror can't send keystrokes")
  func testCopyEmojiWithoutAccessibility() {
    let clipboard = RecordingClipboard()
    let history = EmojiHistoryStore(userDefaults: makeTestUserDefaults())
    let paster = ClipboardPasterStub(canPaste: false)
    var events = [LauncherEvent]()
    let store = makeStore(
      writeToClipboard: clipboard.write,
      emojiHistory: history,
      clipboardPaster: paster,
      onEvent: { events.append($0) }
    )
    store.updateQuery(":face with tears of joy")

    store.openSelectedResult()

    #expect(clipboard.text == "😂")
    #expect(paster.pasteCount == 0)
    #expect(events == [.emojiCopied])
    #expect(history.load().first == "😂")
  }

  @Test("Launcher store: Command-Return copies emoji without pasting")
  func testCommandReturnCopiesEmoji() {
    let clipboard = RecordingClipboard()
    let paster = ClipboardPasterStub()
    var events = [LauncherEvent]()
    let store = makeStore(
      writeToClipboard: clipboard.write,
      clipboardPaster: paster,
      onEvent: { events.append($0) }
    )
    store.updateQuery(":face with tears of joy")

    store.revealSelectedResult()

    #expect(clipboard.text == "😂")
    #expect(paster.pasteCount == 0)
    #expect(events == [.emojiCopied])
  }
}
