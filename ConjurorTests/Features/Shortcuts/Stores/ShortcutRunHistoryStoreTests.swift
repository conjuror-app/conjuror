import Foundation
import XCTest

@testable import Conjuror

final class ShortcutRunHistoryStoreTests: XCTestCase {
  func testRecordsAndReloadsMostRecentSuccessfulRun() {
    let store = ShortcutRunHistoryStore(userDefaults: makeUserDefaults())
    let shortcut = AppleShortcut(
      id: "shortcut-id",
      name: "Lights",
      subtitle: "",
      acceptsInput: false
    )
    let firstDate = Date(timeIntervalSince1970: 10)
    let latestDate = Date(timeIntervalSince1970: 20)

    store.recordRun(of: shortcut, at: firstDate)
    store.recordRun(of: shortcut, at: latestDate)

    XCTAssertEqual(store.load(), [shortcut.persistenceKey: latestDate])
  }

  private func makeUserDefaults() -> UserDefaults {
    let suiteName = "ShortcutRunHistoryStoreTests.\(UUID().uuidString)"
    let userDefaults = UserDefaults(suiteName: suiteName)!
    userDefaults.removePersistentDomain(forName: suiteName)
    return userDefaults
  }
}
