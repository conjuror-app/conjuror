import Foundation
import XCTest

@testable import Conjuror

@MainActor
final class HotKeyStoreTests: XCTestCase {
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
    XCTAssertEqual(store.registrationErrorMessage, "Shortcut unavailable")

    shouldFail = false
    XCTAssertNil(store.updateConfiguration(.defaultValue))
    XCTAssertNil(store.registrationErrorMessage)
    XCTAssertEqual(configurations, [.defaultValue, .defaultValue])
  }

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

    XCTAssertEqual(errorMessage, "Shortcut unavailable")
    XCTAssertEqual(settingsStore.hotKeyConfiguration, .defaultValue)
    XCTAssertNil(store.registrationErrorMessage)
  }

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

    XCTAssertEqual(registrationCount, 2)
    XCTAssertNil(store.registrationErrorMessage)
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
