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

  @Test("App aliases and hotkeys persist, and clearing both removes the app")
  func testApplicationCustomizationsPersist() {
    let userDefaults = makeTestUserDefaults()
    let store = SettingsStore(userDefaults: userDefaults)
    let code = application("Visual Studio Code", id: "com.microsoft.VSCode")
    let hotKey = HotKeyConfiguration(keyCode: 9, modifiers: 2_048, displayName: "⌥ V")

    #expect(store.setAlias(" vs ", for: code) == nil)
    store.setApplicationHotKey(hotKey, for: code)

    let reloaded = SettingsStore(userDefaults: userDefaults)
    #expect(
      reloaded.applicationCustomizations[code.persistenceKey]
        == ApplicationCustomization(
          name: "Visual Studio Code",
          bundleIdentifier: "com.microsoft.VSCode",
          alias: "vs",
          hotKey: hotKey
        )
    )

    #expect(reloaded.setAlias("", for: code) == nil)
    reloaded.setApplicationHotKey(nil, for: code)
    #expect(reloaded.applicationCustomizations.isEmpty)
    #expect(SettingsStore(userDefaults: userDefaults).applicationCustomizations.isEmpty)
  }

  @Test("Invalid aliases are rejected without saving", arguments: ["VS", "v s", ">vs", "/vs"])
  func testInvalidAliases(alias: String) {
    let store = SettingsStore(userDefaults: makeTestUserDefaults())
    let code = application("Visual Studio Code", id: "com.microsoft.VSCode")
    let studio = application("Android Studio", id: "com.google.android.studio")
    #expect(store.setAlias("vs", for: code) == nil)

    #expect(store.setAlias(alias, for: studio) != nil)
    #expect(store.applicationCustomizations[studio.persistenceKey] == nil)
    #expect(store.setAlias("VS", for: code) == nil)
  }

  @Test("Customizations follow a deleted app to its only reinstalled copy")
  func testRelocation() {
    let store = SettingsStore(userDefaults: makeTestUserDefaults())
    let old = application("Code", id: "com.microsoft.VSCode", path: "/Applications/Code.app")
    let moved = application(
      "Code",
      id: "com.microsoft.VSCode",
      path: "/Users/me/Applications/Code.app"
    )
    #expect(store.setAlias("vs", for: old) == nil)

    #expect(!store.relocateApplicationCustomizations(installed: [moved], fileExists: { _ in true }))
    #expect(store.relocateApplicationCustomizations(installed: [moved], fileExists: { _ in false }))
    #expect(store.applicationCustomizations.keys.sorted() == [moved.persistenceKey])
    #expect(store.applicationCustomizations[moved.persistenceKey]?.alias == "vs")
  }

  @Test("Customizations stay put when the new copy is ambiguous, taken, or on another volume")
  func testRelocationIsConservative() {
    let id = "com.microsoft.VSCode"
    let old = application("Code", id: id, path: "/Applications/Code.app")
    let first = application("Code", id: id, path: "/Users/me/Applications/Code.app")
    let second = application("Code", id: id, path: "/Users/me/Downloads/Code.app")
    let external = application("Code", id: id, path: "/Volumes/External/Applications/Code.app")

    let ambiguous = SettingsStore(userDefaults: makeTestUserDefaults())
    #expect(ambiguous.setAlias("vs", for: old) == nil)
    #expect(
      !ambiguous.relocateApplicationCustomizations(
        installed: [first, second],
        fileExists: { _ in false }
      )
    )

    let taken = SettingsStore(userDefaults: makeTestUserDefaults())
    #expect(taken.setAlias("vs", for: old) == nil)
    #expect(taken.setAlias("code", for: first) == nil)
    #expect(
      !taken.relocateApplicationCustomizations(installed: [first], fileExists: { _ in false })
    )

    let unmounted = SettingsStore(userDefaults: makeTestUserDefaults())
    #expect(unmounted.setAlias("vs", for: external) == nil)
    #expect(
      !unmounted.relocateApplicationCustomizations(installed: [first], fileExists: { _ in false })
    )
    #expect(unmounted.applicationCustomizations[external.persistenceKey] != nil)
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

  private func application(
    _ name: String,
    id: String,
    path: String? = nil
  ) -> InstalledApplication {
    InstalledApplication(
      displayName: name,
      bundleIdentifier: id,
      url: URL(fileURLWithPath: path ?? "/Applications/\(name).app")
    )
  }
}

@MainActor
extension SettingsStoreTests {
  @Test("Quicklink edits persist, and removed built-ins stay removed")
  func testQuicklinkEditsPersist() throws {
    let userDefaults = makeTestUserDefaults()
    let store = SettingsStore(userDefaults: userDefaults)
    let github = try #require(store.quicklinks.first { $0.keyword == "gh" })
    let kagi = Quicklink(
      name: "Kagi",
      keyword: "k",
      urlTemplate: "https://kagi.com/search?q={query}"
    )

    #expect(store.quicklinks == Quicklink.builtIns)
    #expect(store.webSearchQuicklink?.name == "DuckDuckGo")

    store.removeQuicklink(id: github.id)
    #expect(store.saveQuicklink(kagi) == nil)
    store.setWebSearchQuicklink(id: kagi.id)

    let reloaded = SettingsStore(userDefaults: userDefaults)
    #expect(reloaded.quicklinks == Quicklink.builtIns.filter { $0.id != github.id } + [kagi])
    #expect(reloaded.webSearchQuicklink == kagi)
  }

  @Test("The web search fallback turns off when its quicklink can no longer search")
  func testWebSearchFallbackTurnsOff() throws {
    let userDefaults = makeTestUserDefaults()
    let store = SettingsStore(userDefaults: userDefaults)
    let engine = try #require(store.webSearchQuicklink)

    let withoutPlaceholder = Quicklink(
      id: engine.id,
      name: engine.name,
      keyword: engine.keyword,
      urlTemplate: "https://duckduckgo.com"
    )
    #expect(store.saveQuicklink(withoutPlaceholder) == nil)

    #expect(store.webSearchQuicklinkID == nil)
    #expect(SettingsStore(userDefaults: userDefaults).webSearchQuicklink == nil)
  }

  @Test("Restoring built-ins keeps edits and leaves taken keywords with their new owner")
  func testRestoreBuiltInQuicklinks() throws {
    let store = SettingsStore(userDefaults: makeTestUserDefaults())
    let google = try #require(store.quicklinks.first { $0.keyword == "g" })
    let github = try #require(store.quicklinks.first { $0.keyword == "gh" })
    let renamedGoogle = Quicklink(
      id: google.id,
      name: "Google UK",
      keyword: "g",
      urlTemplate: "https://www.google.co.uk/search?q={query}"
    )
    let gitHubEnterprise = Quicklink(
      name: "GitHub Enterprise",
      keyword: "gh",
      urlTemplate: "https://github.example.com/search?q={query}"
    )

    #expect(store.saveQuicklink(renamedGoogle) == nil)
    store.removeQuicklink(id: github.id)
    #expect(store.saveQuicklink(gitHubEnterprise) == nil)
    store.restoreBuiltInQuicklinks()

    let restoredGitHub = try #require(store.quicklinks.first { $0.id == github.id })
    #expect(store.quicklinks.first { $0.id == google.id } == renamedGoogle)
    #expect(restoredGitHub.keyword == nil)
    #expect(store.quicklinks.count == Quicklink.builtIns.count + 1)
  }
}
