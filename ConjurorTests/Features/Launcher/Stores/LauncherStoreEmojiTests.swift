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

  @Test("Launcher store: Return copies emoji and records it as recent")
  func testCopyEmoji() {
    let clipboard = RecordingClipboard()
    let userDefaults = makeTestUserDefaults()
    let history = EmojiHistoryStore(userDefaults: userDefaults)
    var didRequestHide = false
    let store = makeStore(
      writeToClipboard: clipboard.write,
      emojiHistory: history,
      onEvent: { if $0 == .emojiCopied { didRequestHide = true } }
    )
    store.updateQuery(":face with tears of joy")

    store.openSelectedResult()

    #expect(clipboard.text == "😂")
    #expect(history.load().first == "😂")
    #expect(didRequestHide)
    #expect(store.mode == .applications)
  }
}
