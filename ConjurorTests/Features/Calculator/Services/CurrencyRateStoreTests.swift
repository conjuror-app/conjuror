import Foundation
import Testing

@testable import Conjuror

@Suite("Currency Rate Store")
@MainActor
struct CurrencyRateStoreTests {
  @Test("Currency rate store: refresh task does not retain the store while sleeping")
  func testRefreshTaskDoesNotRetainStoreWhileSleeping() async throws {
    let userDefaults = makeTestUserDefaults()
    userDefaults.set(true, forKey: "settings.currencyConversionEnabled")
    let cacheURL = FileManager.default.temporaryDirectory
      .appendingPathComponent("CurrencyRateStoreTests-\(UUID().uuidString).json")
    let rates = CurrencyRates(
      base: "USD",
      rates: ["GBP": 0.75],
      rateDate: "2026-08-15",
      fetchedAt: Date()
    )
    try JSONEncoder().encode(rates).write(to: cacheURL)
    defer { try? FileManager.default.removeItem(at: cacheURL) }

    weak var weakStore: CurrencyRateStore?
    do {
      let store = CurrencyRateStore(userDefaults: userDefaults, cacheURL: cacheURL)
      weakStore = store
      store.start()
      await Task.yield()
    }

    for _ in 0..<10 where weakStore != nil {
      await Task.yield()
    }
    #expect(weakStore == nil)
  }
}
