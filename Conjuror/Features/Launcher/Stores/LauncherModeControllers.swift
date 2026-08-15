import Foundation

final class LauncherApplicationController {
  private let history: LaunchHistoryStore
  private var index = ApplicationRanker.Index(applications: [])
  private var recentUses: [String: Date]

  init(history: LaunchHistoryStore) {
    self.history = history
    recentUses = history.load()
  }

  func replace(_ applications: [InstalledApplication]) {
    index = ApplicationRanker.Index(applications: applications)
  }

  func ranked(query: String) -> [InstalledApplication] {
    index.ranked(query: query, recentLaunches: recentUses)
  }

  func record(_ application: InstalledApplication) {
    history.recordLaunch(of: application)
    recentUses = history.load()
  }
}

final class LauncherShortcutController {
  private let history: ShortcutRunHistoryStore
  private var index = ShortcutRanker.Index(shortcuts: [])
  private var recentUses: [String: Date]

  init(history: ShortcutRunHistoryStore) {
    self.history = history
    recentUses = history.load()
  }

  func replace(_ shortcuts: [AppleShortcut]) {
    index = ShortcutRanker.Index(shortcuts: shortcuts)
  }

  func ranked(query: String) -> [AppleShortcut] {
    index.ranked(query: query, recentRuns: recentUses)
  }

  func record(_ shortcut: AppleShortcut) {
    history.recordRun(of: shortcut)
    recentUses = history.load()
  }
}
