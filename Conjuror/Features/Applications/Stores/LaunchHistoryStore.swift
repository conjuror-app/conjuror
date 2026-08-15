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
