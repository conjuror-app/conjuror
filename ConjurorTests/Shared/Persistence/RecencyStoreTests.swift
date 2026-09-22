import Foundation
import Testing

@testable import Conjuror

@Suite("Recency Store")
struct RecencyStoreTests {
  @Test("Invalid stored representations are ignored")
  func testInvalidStoredRepresentationIsIgnored() {
    let userDefaults = makeTestUserDefaults()
    userDefaults.set(["invalid": "date"], forKey: "recency")
    let store = RecencyStore(storageKey: "recency", limit: 100, userDefaults: userDefaults)

    #expect(store.load().isEmpty)
  }

  @Test("The latest use is recorded and reloaded")
  func testRecordsAndReloadsLatestUse() {
    let store = RecencyStore(
      storageKey: "recency",
      limit: 100,
      userDefaults: makeTestUserDefaults()
    )
    let firstDate = Date(timeIntervalSince1970: 10)
    let latestDate = Date(timeIntervalSince1970: 20)

    store.record(key: "item", at: firstDate)
    store.record(key: "item", at: latestDate)

    #expect(store.load() == ["item": latestDate])
  }

  @Test("Only the configured number of uses are retained")
  func testLimitsHistoryToConfiguredCount() {
    let userDefaults = makeTestUserDefaults()
    let store = RecencyStore(storageKey: "recency", limit: 100, userDefaults: userDefaults)

    for index in 0..<101 {
      store.record(key: "item-\(index)", at: Date(timeIntervalSince1970: Double(index)))
    }

    let history = store.load()
    #expect(history.count == 100)
    #expect(userDefaults.dictionary(forKey: "recency")?.count == 100)
    #expect(history["item-0"] == nil)
    #expect(history["item-100"] != nil)
  }
}
