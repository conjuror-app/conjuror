import Foundation

struct ShortcutRunHistoryStore {
  private static let storageKey = "recentSuccessfulShortcutRuns"

  private let userDefaults: UserDefaults

  init(userDefaults: UserDefaults = .standard) {
    self.userDefaults = userDefaults
  }

  func load() -> [String: Date] {
    guard let storedValues = userDefaults.dictionary(forKey: Self.storageKey) as? [String: Double]
    else {
      return [:]
    }
    return storedValues.mapValues(Date.init(timeIntervalSince1970:))
  }

  func recordRun(of shortcut: AppleShortcut, at date: Date = Date()) {
    var runs = load()
    runs[shortcut.persistenceKey] = date
    userDefaults.set(runs.mapValues(\.timeIntervalSince1970), forKey: Self.storageKey)
  }
}
