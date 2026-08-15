import Foundation

struct LaunchHistoryStore {
  private let store: RecencyStore

  init(userDefaults: UserDefaults = .standard) {
    store = RecencyStore(
      storageKey: "recentSuccessfulLaunches",
      limit: 100,
      userDefaults: userDefaults
    )
  }

  func load() -> [String: Date] {
    store.load()
  }

  func recordLaunch(of application: InstalledApplication, at date: Date = Date()) {
    store.record(key: application.persistenceKey, at: date)
  }
}

struct RecencyStore {
  private let storageKey: String
  private let limit: Int
  private let userDefaults: UserDefaults

  init(storageKey: String, limit: Int, userDefaults: UserDefaults = .standard) {
    self.storageKey = storageKey
    self.limit = limit
    self.userDefaults = userDefaults
  }

  func load() -> [String: Date] {
    guard let values = userDefaults.dictionary(forKey: storageKey) as? [String: Double] else {
      return [:]
    }
    return limited(values).mapValues(Date.init(timeIntervalSince1970:))
  }

  func record(key: String, at date: Date = Date()) {
    var values = load()
    values[key] = date
    userDefaults.set(
      limited(values.mapValues(\.timeIntervalSince1970)),
      forKey: storageKey
    )
  }

  private func limited(_ values: [String: Double]) -> [String: Double] {
    Dictionary(
      uniqueKeysWithValues:
        values
        .sorted { $0.value > $1.value }
        .prefix(limit)
        .map { ($0.key, $0.value) }
    )
  }
}
