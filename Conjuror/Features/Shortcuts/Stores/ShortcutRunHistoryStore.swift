import Foundation

struct ShortcutRunHistoryStore {
  private static let storageKey = "recentSuccessfulShortcutRuns"
  private static let limit = 100

  private static func limited(_ values: [String: Double]) -> [String: Double] {
    Dictionary(
      uniqueKeysWithValues:
        values
        .sorted { $0.value > $1.value }
        .prefix(Self.limit)
        .map { ($0.key, $0.value) }
    )
  }

  private let userDefaults: UserDefaults

  init(userDefaults: UserDefaults = .standard) {
    self.userDefaults = userDefaults
  }

  func load() -> [String: Date] {
    guard let storedValues = userDefaults.dictionary(forKey: Self.storageKey) as? [String: Double]
    else {
      return [:]
    }
    return Self.limited(storedValues).mapValues(Date.init(timeIntervalSince1970:))
  }

  func recordRun(of shortcut: AppleShortcut, at date: Date = Date()) {
    var runs = load()
    runs[shortcut.persistenceKey] = date
    let storedValues = Self.limited(runs.mapValues(\.timeIntervalSince1970))
    userDefaults.set(storedValues, forKey: Self.storageKey)
  }
}
