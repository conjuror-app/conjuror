import Foundation
import Testing

@testable import Conjuror

@MainActor
@Suite("Settings Store")
struct SettingsStoreTests {
  @Test("Default values are used without stored settings")
  func testDefaults() {
    let userDefaults = makeTestUserDefaults()
    let store = SettingsStore(userDefaults: userDefaults)

    #expect(store.hotKeyConfiguration == .defaultValue)
    #expect(store.hotKeyConfiguration(for: .files) == HotKeyAction.files.defaultConfiguration)
    #expect(store.maximumVisibleResults == SettingsStore.defaultMaximumVisibleResults)
    #expect(store.preferredEmojiSkinTone == .default)
    #expect(store.isFilesModuleEnabled)
    #expect(store.showsSystemSettingsItems)
    #expect(store.excludedApplications.isEmpty)
    #expect(store.launcherBorderStyle == .cyan)
    #expect(store.launcherAppearance == .standard)
    #expect(store.launcherCustomBorderColor == .default)
  }

  @Test("Updated settings persist")
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
    store.setShowsSystemSettingsItems(false)
    store.setLauncherBorderStyle(.custom)
    store.setLauncherAppearance(.minimal)
    store.setLauncherCustomBorderColor(LauncherBorderColor(red: 0.1, green: 0.2, blue: 0.3))

    let reloadedStore = SettingsStore(userDefaults: userDefaults)
    #expect(reloadedStore.hotKeyConfiguration == hotKey)
    #expect(reloadedStore.maximumVisibleResults == 9)
    #expect(reloadedStore.preferredEmojiSkinTone == .mediumDark)
    #expect(!reloadedStore.isFilesModuleEnabled)
    #expect(!reloadedStore.showsSystemSettingsItems)
    #expect(reloadedStore.launcherBorderStyle == .custom)
    #expect(reloadedStore.launcherAppearance == .minimal)
    #expect(
      reloadedStore.launcherCustomBorderColor
        == LauncherBorderColor(red: 0.1, green: 0.2, blue: 0.3)
    )
  }

  @Test("App exclusions persist, deduplicate, and can be removed after the app disappears")
  func testApplicationExclusionsPersist() {
    let defaults = makeTestUserDefaults()
    let store = SettingsStore(userDefaults: defaults)
    let application = InstalledApplication(
      displayName: "Example",
      bundleIdentifier: "dev.example.app",
      url: URL(fileURLWithPath: "/Applications/Example.app")
    )
    store.excludeApplication(application)
    store.excludeApplication(application)

    let reloaded = SettingsStore(userDefaults: defaults)
    #expect(reloaded.excludedApplications == [application.persistenceKey: "Example"])
    reloaded.removeExcludedApplication(at: application.persistenceKey)
    #expect(SettingsStore(userDefaults: defaults).excludedApplications.isEmpty)

    reloaded.excludeApplication(application)
    reloaded.resetToDefaults()
    #expect(SettingsStore(userDefaults: defaults).excludedApplications.isEmpty)
  }

  @Test("Existing hotkey persistence keys remain compatible")
  func testLoadsExistingHotKeyPersistenceKeys() {
    let userDefaults = makeTestUserDefaults()
    let actionsAndPrefixes: [(HotKeyAction, String)] = [
      (.launcher, "settings.hotKey"),
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

  @Test("Invalid hotkey integers fall back to the default", arguments: [-1, Int(UInt32.max) + 1])
  func testInvalidHotKeyIntegers(value: Int) {
    for key in ["settings.hotKeyCode", "settings.hotKeyModifiers"] {
      let defaults = makeTestUserDefaults()
      defaults.set(1, forKey: "settings.hotKeyCode")
      defaults.set(2, forKey: "settings.hotKeyModifiers")
      defaults.set("Invalid shortcut", forKey: "settings.hotKeyDisplayName")
      defaults.set(value, forKey: key)

      let store = SettingsStore(userDefaults: defaults)

      #expect(store.hotKeyConfiguration == .defaultValue)
    }
  }

  @Test("Maximum visible results are clamped and the default resets")
  func testResultLimit() {
    let store = SettingsStore(userDefaults: makeTestUserDefaults())

    store.setMaximumVisibleResults(100)
    #expect(store.maximumVisibleResults == SettingsStore.maximumVisibleResultsRange.upperBound)

    store.resetMaximumVisibleResults()
    #expect(store.maximumVisibleResults == SettingsStore.defaultMaximumVisibleResults)
  }
}
