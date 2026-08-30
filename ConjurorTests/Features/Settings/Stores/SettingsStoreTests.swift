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
    #expect(store.clipboardHotKeyConfiguration == nil)
    #expect(!store.isClipboardHistoryEnabled)
    #expect(store.filesHotKeyConfiguration == HotKeyAction.files.defaultConfiguration)
    #expect(store.maximumVisibleResults == SettingsStore.defaultMaximumVisibleResults)
    #expect(store.preferredEmojiSkinTone == .default)
    #expect(store.isFilesModuleEnabled)
    #expect(store.showsSystemSettingsItems)
    #expect(store.launcherBorderStyle == .cyan)
    #expect(store.launcherAppearance == .standard)
    #expect(store.launcherCustomBorderColor == .default)
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
    store.setFilesModuleEnabled(false)
    store.setClipboardHistoryEnabled(true)
    store.setHotKeyConfiguration(HotKeyAction.clipboard.defaultConfiguration, for: .clipboard)
    store.setShowsSystemSettingsItems(false)
    store.setLauncherBorderStyle(.custom)
    store.setLauncherAppearance(.minimal)
    store.setLauncherCustomBorderColor(LauncherBorderColor(red: 0.1, green: 0.2, blue: 0.3))

    let reloadedStore = SettingsStore(userDefaults: userDefaults)
    #expect(reloadedStore.hotKeyConfiguration == hotKey)
    #expect(reloadedStore.maximumVisibleResults == 9)
    #expect(reloadedStore.preferredEmojiSkinTone == .mediumDark)
    #expect(!reloadedStore.isFilesModuleEnabled)
    #expect(reloadedStore.isClipboardHistoryEnabled)
    #expect(
      reloadedStore.clipboardHotKeyConfiguration == HotKeyAction.clipboard.defaultConfiguration
    )
    #expect(!reloadedStore.showsSystemSettingsItems)
    #expect(reloadedStore.launcherBorderStyle == .custom)
    #expect(reloadedStore.launcherAppearance == .minimal)
    #expect(
      reloadedStore.launcherCustomBorderColor
        == LauncherBorderColor(red: 0.1, green: 0.2, blue: 0.3)
    )
  }

  @Test("Settings store: existing hotkey persistence keys remain compatible")
  func testLoadsExistingHotKeyPersistenceKeys() {
    let userDefaults = makeTestUserDefaults()
    let actionsAndPrefixes: [(HotKeyAction, String)] = [
      (.launcher, "settings.hotKey"),
      (.clipboard, "settings.clipboardHotKey"),
      (.shortcuts, "settings.shortcutsHotKey"),
      (.emoji, "settings.emojiHotKey"),
      (.files, "settings.filesHotKey"),
    ]

    for (index, (_, prefix)) in actionsAndPrefixes.enumerated() {
      userDefaults.set(index + 1, forKey: "\(prefix)Code")
      userDefaults.set(index + 5, forKey: "\(prefix)Modifiers")
      userDefaults.set("Shortcut \(index)", forKey: "\(prefix)DisplayName")
    }

    let store = SettingsStore(userDefaults: userDefaults)
    for (index, (action, _)) in actionsAndPrefixes.enumerated() {
      #expect(
        store.hotKeyConfiguration(for: action)
          == HotKeyConfiguration(
            keyCode: UInt32(index + 1),
            modifiers: UInt32(index + 5),
            displayName: "Shortcut \(index)"
          )
      )
    }
  }

  @Test("Settings store: maximum visible results are clamped and the default resets")
  func testClampsMaximumVisibleResultsAndResetsDefault() {
    let store = SettingsStore(userDefaults: makeTestUserDefaults())

    store.setMaximumVisibleResults(100)
    #expect(store.maximumVisibleResults == SettingsStore.maximumVisibleResultsRange.upperBound)

    store.resetMaximumVisibleResults()
    #expect(store.maximumVisibleResults == SettingsStore.defaultMaximumVisibleResults)
  }
}
