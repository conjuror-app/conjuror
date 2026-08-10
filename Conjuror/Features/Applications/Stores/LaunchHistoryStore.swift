import Foundation

struct LaunchHistoryStore {
  private static let storageKey = "recentSuccessfulLaunches"

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

  func recordLaunch(of application: InstalledApplication, at date: Date = Date()) {
    var launches = load()
    launches[application.persistenceKey] = date

    let storedValues = launches.mapValues(\.timeIntervalSince1970)
    userDefaults.set(storedValues, forKey: Self.storageKey)
  }
}
