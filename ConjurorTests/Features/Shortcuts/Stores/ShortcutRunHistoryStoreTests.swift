import Foundation
import Testing

@testable import Conjuror

@Suite("Shortcut Run History Store")
struct ShortcutRunHistoryStoreTests {
  @Test("Shortcut run history store: most recent successful runs are recorded and reloaded")
  func testRecordsAndReloadsMostRecentSuccessfulRun() {
    let store = ShortcutRunHistoryStore(userDefaults: makeTestUserDefaults())
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

    #expect(store.load() == [shortcut.persistenceKey: latestDate])
  }

  @Test("Shortcut run history store: only the 100 most recent runs are retained")
  func testLimitsHistoryToMostRecentRuns() {
    let userDefaults = makeTestUserDefaults()
    let store = ShortcutRunHistoryStore(userDefaults: userDefaults)

    for index in 0..<101 {
      let shortcut = AppleShortcut(
        id: "shortcut-\(index)",
        name: "Shortcut \(index)",
        subtitle: "",
        acceptsInput: false
      )
      store.recordRun(of: shortcut, at: Date(timeIntervalSince1970: Double(index)))
    }

    let history = store.load()
    #expect(history.count == 100)
    #expect(userDefaults.dictionary(forKey: "recentSuccessfulShortcutRuns")?.count == 100)
    #expect(history["shortcut:shortcut-0"] == nil)
    #expect(history["shortcut:shortcut-100"] != nil)
  }

  private func makeTestUserDefaults() -> UserDefaults {
    let suiteName = "ShortcutRunHistoryStoreTests.\(UUID().uuidString)"
    let userDefaults = UserDefaults(suiteName: suiteName)!
    userDefaults.removePersistentDomain(forName: suiteName)
    return userDefaults
  }
}
