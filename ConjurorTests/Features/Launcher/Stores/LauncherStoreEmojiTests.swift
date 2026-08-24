import AppKit
import Testing

@testable import Conjuror

@MainActor
extension LauncherStoreTests {
  @Test("Launcher store: preferred skin tone replaces tone-capable base emoji")
  func testPreferredSkinToneReplacesToneCapableBaseEmoji() {
    let settings = SettingsStore(userDefaults: makeTestUserDefaults())
    settings.setPreferredEmojiSkinTone(.mediumDark)
    let store = makeStore(settingsStore: settings)

    store.updateQuery(":waving hand")

    #expect(store.displayedEmoji.first?.value == "👋🏾")
    #expect(!(store.displayedEmoji.contains { $0.value == "👋" }))
  }

  @Test("Launcher store: preferred skin tone replaces gendered couple emoji")
  func testPreferredSkinToneReplacesGenderedCoupleEmoji() {
    let settings = SettingsStore(userDefaults: makeTestUserDefaults())
    settings.setPreferredEmojiSkinTone(.mediumDark)
    let store = makeStore(settingsStore: settings)

    store.updateQuery(":kiss woman man")

    #expect(store.displayedEmoji.first?.value == "👩🏾‍❤️‍💋‍👨🏾")
    #expect(!(store.displayedEmoji.contains { $0.value == "👩‍❤️‍💋‍👨" }))
  }

  @Test("Launcher store: colon switches to emoji and filters following text")
  func testColonSwitchesToEmojiAndFiltersFollowingText() {
    let store = makeStore()

    store.updateQuery(":waving hand medium dark")

    #expect(store.mode == .emoji)
    #expect(store.query == "waving hand medium dark")
    #expect(store.filteredEmoji.first?.value == "👋🏾")
  }

  @Test("Launcher store: horizontal arrows navigate the emoji grid")
  func testHorizontalArrowsNavigateEmojiGrid() {
    let store = makeStore(
      catalog: CatalogStub(applications: []),
      launcher: LauncherStub(),
      launchHistory: RecencyStore.applicationLaunches(userDefaults: makeTestUserDefaults()),
      emojiHistory: EmojiHistoryStore(userDefaults: makeTestUserDefaults())
    )
    store.updateQuery(":")
    let firstID = store.selectedEmojiID

    store.moveSelection(.right)
    #expect(store.selectedEmojiID == store.displayedEmoji[1].id)

    store.moveSelection(.left)
    #expect(store.selectedEmojiID == firstID)
  }

  @Test("Launcher store: Return copies emoji and records it as recent")
  func testReturnCopiesEmojiAndRecordsItAsRecent() {
    let clipboard = RecordingCalculatorClipboard()
    let userDefaults = makeTestUserDefaults()
    let history = EmojiHistoryStore(userDefaults: userDefaults)
    var didRequestHide = false
    let store = makeStore(
      catalog: CatalogStub(applications: []),
      calculatorClipboard: clipboard,
      launcher: LauncherStub(),
      launchHistory: RecencyStore.applicationLaunches(userDefaults: makeTestUserDefaults()),
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
