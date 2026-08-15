import Foundation
import Testing

@testable import Conjuror

@MainActor
@Suite("Hot Key Store")
struct HotKeyStoreTests {
  @Test("Hot key store: registration failures are published and successful retries clear them")
  func testRegistrationFailureIsPublishedAndSuccessfulRetryClearsIt() {
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
    #expect((store.updateConfiguration(.defaultValue)) == nil)
    #expect((store.registrationErrorMessage) == nil)
    #expect(configurations == [.defaultValue, .defaultValue])
  }

  @Test("Hot key store: rejected replacements do not persist configuration")
  func testRejectedReplacementDoesNotPersistConfiguration() {
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
    #expect((store.registrationErrorMessage) == nil)
  }

  @Test("Hot key store: recording temporarily unregisters and restores the shortcuts")
  func testRecordingTemporarilyUnregistersAndRestoresShortcuts() {
    let settingsStore = SettingsStore(userDefaults: makeTestUserDefaults())
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
    #expect((store.registrationErrorMessage) == nil)
  }

  @Test("Hot key store: changing a shortcut while recording restores every shortcut")
  func testChangingShortcutWhileRecordingRestoresEveryShortcut() {
    let settingsStore = SettingsStore(userDefaults: makeTestUserDefaults())
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
    #expect((store.updateConfiguration(replacement)) == nil)
    store.setShortcutRecording(false)

    #expect(configurations.suffix(HotKeyAction.allCases.count).contains(replacement))
    #expect(configurations.count == HotKeyAction.allCases.count * 2 + 1)
    #expect((store.registrationErrorMessage) == nil)
  }

  private func makeTestUserDefaults() -> UserDefaults {
    let suiteName = "HotKeyStoreTests.\(UUID().uuidString)"
    let userDefaults = UserDefaults(suiteName: suiteName)!
    userDefaults.removePersistentDomain(forName: suiteName)
    return userDefaults
  }
}

private final class RegistrationToken: HotKeyRegistration {}

private enum RegistrationError: LocalizedError {
  case unavailable

  var errorDescription: String? {
    "Shortcut unavailable"
  }
}
