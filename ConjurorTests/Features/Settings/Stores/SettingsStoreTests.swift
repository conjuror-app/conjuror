import Foundation
import Testing

@testable import Conjuror

@MainActor
@Suite("Settings Store")
struct SettingsStoreTests {
  @Test("Settings store: default values are used without stored settings")
  func testUsesDefaultValuesWithoutStoredSettings() {
    let userDefaults = makeTestUserDefaults()
    let store = SettingsStore(userDefaults: userDefaults)

    #expect(store.hotKeyConfiguration == .defaultValue)
    #expect(store.filesHotKeyConfiguration == HotKeyAction.files.defaultConfiguration)
    #expect(store.maximumVisibleResults == SettingsStore.defaultMaximumVisibleResults)
    #expect(store.preferredEmojiSkinTone == .default)
  }

  @Test("Settings store: updated settings persist")
  func testPersistsUpdatedSettings() {
    let userDefaults = makeTestUserDefaults()
    let store = SettingsStore(userDefaults: userDefaults)
    let hotKey = HotKeyConfiguration(
      keyCode: 1,
      modifiers: 2,
      displayName: "⌘ A"
    )

    store.setHotKeyConfiguration(hotKey)
    store.setMaximumVisibleResults(9)
    store.setPreferredEmojiSkinTone(.mediumDark)

    let reloadedStore = SettingsStore(userDefaults: userDefaults)
    #expect(reloadedStore.hotKeyConfiguration == hotKey)
    #expect(reloadedStore.maximumVisibleResults == 9)
    #expect(reloadedStore.preferredEmojiSkinTone == .mediumDark)
  }

  @Test("Settings store: maximum visible results are clamped and the default resets")
  func testClampsMaximumVisibleResultsAndResetsDefault() {
    let store = SettingsStore(userDefaults: makeTestUserDefaults())

    store.setMaximumVisibleResults(100)
    #expect(store.maximumVisibleResults == SettingsStore.maximumVisibleResultsRange.upperBound)

    store.resetMaximumVisibleResults()
    #expect(store.maximumVisibleResults == SettingsStore.defaultMaximumVisibleResults)
  }

  private func makeTestUserDefaults() -> UserDefaults {
    let suiteName = "SettingsStoreTests.\(UUID().uuidString)"
    let userDefaults = UserDefaults(suiteName: suiteName)!
    userDefaults.removePersistentDomain(forName: suiteName)
    return userDefaults
  }
}
