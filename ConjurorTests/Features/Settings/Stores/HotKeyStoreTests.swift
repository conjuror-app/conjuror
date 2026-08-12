import Foundation
import Testing

@testable import Conjuror

@MainActor
@Suite("Hot Key Store")
struct HotKeyStoreTests {
  @Test("Hot key store: registration failures are published and successful retries clear them")
  func testRegistrationFailureIsPublishedAndSuccessfulRetryClearsIt() {
    let settingsStore = SettingsStore(userDefaults: makeUserDefaults())
    var shouldFail = true
    var configurations = [HotKeyConfiguration]()
    let store = HotKeyStore(
      settingsStore: settingsStore,
      onHotKeyPressed: {},
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
    let settingsStore = SettingsStore(userDefaults: makeUserDefaults())
    let replacement = HotKeyConfiguration(
      keyCode: 1,
      modifiers: 2,
      displayName: "⌘ S"
    )
    let store = HotKeyStore(
      settingsStore: settingsStore,
      onHotKeyPressed: {},
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

  @Test("Hot key store: recording temporarily unregisters and restores the shortcut")
  func testRecordingTemporarilyUnregistersAndRestoresShortcut() {
    let settingsStore = SettingsStore(userDefaults: makeUserDefaults())
    var registrationCount = 0
    let store = HotKeyStore(
      settingsStore: settingsStore,
      onHotKeyPressed: {},
      registrationFactory: { _, _ in
        registrationCount += 1
        return RegistrationToken()
      }
    )

    store.register()
    store.setShortcutRecording(true)
    store.setShortcutRecording(false)

    #expect(registrationCount == 2)
    #expect((store.registrationErrorMessage) == nil)
  }

  private func makeUserDefaults() -> UserDefaults {
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
