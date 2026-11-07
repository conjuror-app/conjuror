import Foundation
import Testing

@testable import Conjuror

@MainActor
@Suite("Hot Key Store")
struct HotKeyStoreTests {
  @Test("Registration failures are published and successful retries clear them")
  func testRegistrationRetry() {
    let settingsStore = SettingsStore(userDefaults: makeTestUserDefaults())
    var shouldFail = true
    var configurations = [HotKeyConfiguration]()
    let store = HotKeyStore(
      settingsStore: settingsStore,
      onHotKeyPressed: { _ in },
      registrationFactory: { configuration, _ in
        configurations.append(configuration)

        if shouldFail {
          throw RegistrationError.unavailable
        }

        return RegistrationToken()
      }
    )

    store.register()
    #expect(store.registrationErrorMessage == "Shortcut unavailable")

    shouldFail = false
    #expect(store.updateConfiguration(.defaultValue) == nil)
    #expect(store.registrationErrorMessage == nil)
    #expect(configurations.first == .defaultValue)
    #expect(configurations.last == .defaultValue)
  }

  @Test("Rejected replacements do not persist configuration")
  func testRejectedReplacement() {
    let settingsStore = SettingsStore(userDefaults: makeTestUserDefaults())
    let replacement = HotKeyConfiguration(
      keyCode: 1,
      modifiers: 2,
      displayName: "⌘ S"
    )
    let store = HotKeyStore(
      settingsStore: settingsStore,
      onHotKeyPressed: { _ in },
      registrationFactory: { configuration, _ in
        if configuration == replacement {
          throw RegistrationError.unavailable
        }

        return RegistrationToken()
      }
    )

    store.register()
    let errorMessage = store.updateConfiguration(replacement)

    #expect(errorMessage == "Shortcut unavailable")
    #expect(settingsStore.hotKeyConfiguration == .defaultValue)
    #expect(store.registrationErrorMessage == nil)
  }

  @Test("Recording temporarily unregisters and restores the shortcuts")
  func testRecordingRestoresShortcuts() {
    let settingsStore = SettingsStore(userDefaults: makeTestUserDefaults())
    settingsStore.setClipboardHistoryEnabled(true)
    var registrationCount = 0
    let store = HotKeyStore(
      settingsStore: settingsStore,
      onHotKeyPressed: { _ in },
      registrationFactory: { _, _ in
        registrationCount += 1

        return RegistrationToken()
      }
    )

    store.register()
    store.setShortcutRecording(true)
    store.setShortcutRecording(false)

    #expect(registrationCount == HotKeyAction.allCases.count * 2)
    #expect(store.registrationErrorMessage == nil)
  }

  @Test("Clipboard history's shortcut is registered only while history is on")
  func testClipboardShortcutFollowsSetting() {
    let settingsStore = SettingsStore(userDefaults: makeTestUserDefaults())
    var registered = [HotKeyConfiguration]()
    let store = HotKeyStore(
      settingsStore: settingsStore,
      onHotKeyPressed: { _ in },
      registrationFactory: { configuration, _ in
        registered.append(configuration)

        return RegistrationToken()
      }
    )
    let clipboardShortcut = HotKeyAction.clipboard.defaultConfiguration

    store.register()
    #expect(!registered.contains(clipboardShortcut))

    settingsStore.setClipboardHistoryEnabled(true)
    store.register()
    #expect(registered.contains(clipboardShortcut))
  }

  @Test("Changing a shortcut while recording restores every shortcut")
  func testRecordingReplacement() {
    let settingsStore = SettingsStore(userDefaults: makeTestUserDefaults())
    settingsStore.setClipboardHistoryEnabled(true)
    var configurations = [HotKeyConfiguration]()
    let replacement = HotKeyConfiguration(
      keyCode: 1,
      modifiers: 2,
      displayName: "⌘ S"
    )
    let store = HotKeyStore(
      settingsStore: settingsStore,
      onHotKeyPressed: { _ in },
      registrationFactory: { configuration, _ in
        configurations.append(configuration)

        return RegistrationToken()
      }
    )

    store.register()
    store.setShortcutRecording(true)
    #expect(store.updateConfiguration(replacement) == nil)
    store.setShortcutRecording(false)

    #expect(configurations.suffix(HotKeyAction.allCases.count).contains(replacement))
    #expect(configurations.count == HotKeyAction.allCases.count * 2 + 1)
    #expect(store.registrationErrorMessage == nil)
  }

  @Test("App hotkeys can't reuse the launcher's or another app's keys")
  func testApplicationHotKeyConflicts() {
    let settingsStore = SettingsStore(userDefaults: makeTestUserDefaults())
    let store = HotKeyStore(
      settingsStore: settingsStore,
      onHotKeyPressed: { _ in },
      registrationFactory: { _, _ in RegistrationToken() }
    )
    let code = application("Visual Studio Code")
    let notes = application("Notes")
    let hotKey = HotKeyConfiguration(keyCode: 9, modifiers: 2_048, displayName: "⌥ V")
    store.register()

    #expect(
      store.updateHotKey(.defaultValue, for: code)
        == "That shortcut is already used by the launcher."
    )
    #expect(store.updateHotKey(hotKey, for: code) == nil)
    #expect(
      store.updateHotKey(hotKey, for: notes)
        == "That shortcut is already used by Visual Studio Code."
    )
    #expect(
      store.updateConfiguration(hotKey, for: .launcher)
        == "That shortcut is already used by Visual Studio Code."
    )
    #expect(settingsStore.applicationCustomizations[notes.persistenceKey] == nil)
    #expect(settingsStore.hotKeyConfiguration == .defaultValue)
  }

  @Test("An unavailable app hotkey doesn't stop the launcher hotkey registering")
  func testPartialRegistration() {
    let userDefaults = makeTestUserDefaults()
    let settingsStore = SettingsStore(userDefaults: userDefaults)
    let code = application("Visual Studio Code")
    let hotKey = HotKeyConfiguration(keyCode: 9, modifiers: 2_048, displayName: "⌥ V")
    settingsStore.setApplicationHotKey(hotKey, for: code)
    var registered = [HotKeyConfiguration]()
    let store = HotKeyStore(
      settingsStore: settingsStore,
      onHotKeyPressed: { _ in },
      registrationFactory: { configuration, _ in
        if configuration == hotKey { throw RegistrationError.unavailable }

        registered.append(configuration)

        return RegistrationToken()
      }
    )

    store.register()

    #expect(registered.contains(.defaultValue))
    #expect(store.registrationErrorMessage == "Shortcut unavailable")
  }

  @Test("App hotkeys report their app when pressed and release when cleared")
  func testApplicationHotKeyLifecycle() {
    let settingsStore = SettingsStore(userDefaults: makeTestUserDefaults())
    let code = application("Visual Studio Code")
    let hotKey = HotKeyConfiguration(keyCode: 9, modifiers: 2_048, displayName: "⌥ V")
    var handlers = [(configuration: HotKeyConfiguration, handler: () -> Void)]()
    var pressed = [HotKeyTarget]()
    weak var appRegistration: RegistrationToken?
    let store = HotKeyStore(
      settingsStore: settingsStore,
      onHotKeyPressed: { pressed.append($0) },
      registrationFactory: { configuration, handler in
        handlers.append((configuration, handler))
        let token = RegistrationToken()
        if configuration == hotKey { appRegistration = token }

        return token
      }
    )
    store.register()

    #expect(store.updateHotKey(hotKey, for: code) == nil)
    handlers.last { $0.configuration == hotKey }?.handler()
    #expect(pressed == [.application(path: code.persistenceKey)])
    #expect(appRegistration != nil)

    store.removeApplicationCustomization(at: code.persistenceKey)
    #expect(appRegistration == nil)
    #expect(settingsStore.applicationCustomizations.isEmpty)
  }

  private func application(_ name: String) -> InstalledApplication {
    InstalledApplication(
      displayName: name,
      bundleIdentifier: "dev.example.\(name)",
      url: URL(fileURLWithPath: "/Applications/\(name).app")
    )
  }
}

private final class RegistrationToken {}

private enum RegistrationError: LocalizedError {
  case unavailable

  var errorDescription: String? {
    "Shortcut unavailable"
  }
}
