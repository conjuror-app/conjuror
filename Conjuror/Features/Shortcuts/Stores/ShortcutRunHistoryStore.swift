import Foundation

struct ShortcutRunHistoryStore {
  private let store: RecencyStore

  init(userDefaults: UserDefaults = .standard) {
    store = RecencyStore(
      storageKey: "recentSuccessfulShortcutRuns",
      limit: 100,
      userDefaults: userDefaults
    )
  }

  func load() -> [String: Date] {
    store.load()
  }

  func recordRun(of shortcut: AppleShortcut, at date: Date = Date()) {
    store.record(key: shortcut.persistenceKey, at: date)
  }
}
