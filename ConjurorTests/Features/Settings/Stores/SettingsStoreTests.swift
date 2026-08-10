import Foundation
import XCTest

@testable import Conjuror

@MainActor
final class SettingsStoreTests: XCTestCase {
  func testUsesDefaultValuesWithoutStoredSettings() {
    let userDefaults = makeUserDefaults()
    let store = SettingsStore(userDefaults: userDefaults)

    XCTAssertEqual(store.hotKeyConfiguration, .defaultValue)
    XCTAssertEqual(
      store.maximumVisibleResults,
      SettingsStore.defaultMaximumVisibleResults
    )
  }

  func testPersistsUpdatedSettings() {
    let userDefaults = makeUserDefaults()
    let store = SettingsStore(userDefaults: userDefaults)
    let hotKey = HotKeyConfiguration(
      keyCode: 1,
      modifiers: 2,
      displayName: "⌘ A"
    )

    store.setHotKeyConfiguration(hotKey)
    store.setMaximumVisibleResults(9)

    let reloadedStore = SettingsStore(userDefaults: userDefaults)
    XCTAssertEqual(reloadedStore.hotKeyConfiguration, hotKey)
    XCTAssertEqual(reloadedStore.maximumVisibleResults, 9)
  }

  func testClampsMaximumVisibleResultsAndResetsDefault() {
    let store = SettingsStore(userDefaults: makeUserDefaults())

    store.setMaximumVisibleResults(100)
    XCTAssertEqual(
      store.maximumVisibleResults,
      SettingsStore.maximumVisibleResultsRange.upperBound
    )

    store.resetMaximumVisibleResults()
    XCTAssertEqual(
      store.maximumVisibleResults,
      SettingsStore.defaultMaximumVisibleResults
    )
  }

  private func makeUserDefaults() -> UserDefaults {
    let suiteName = "SettingsStoreTests.\(UUID().uuidString)"
    let userDefaults = UserDefaults(suiteName: suiteName)!
    userDefaults.removePersistentDomain(forName: suiteName)
    return userDefaults
  }
}
