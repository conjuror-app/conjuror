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

@MainActor
final class LauncherFileController {
  static let minimumQueryLength = 2

  enum Update {
    case cleared
    case searching
    case results([FileSearchResult])
    case failed(Error)
  }

  private let searcher: FileSearching
  private var task: Task<Void, Never>?

  init(searcher: FileSearching) {
    self.searcher = searcher
  }

  deinit {
    task?.cancel()
  }

  func search(query: String, onUpdate: @escaping (Update) -> Void) {
    task?.cancel()
    let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
    guard query.count >= Self.minimumQueryLength else {
      onUpdate(.cleared)
      return
    }

    onUpdate(.searching)
    let searcher = searcher
    task = Task {
      do {
        try await Task.sleep(for: .milliseconds(200))
        let results = try await searcher.search(query: query)
        guard !Task.isCancelled else { return }
        onUpdate(.results(results))
      } catch is CancellationError {
      } catch {
        guard !Task.isCancelled else { return }
        onUpdate(.failed(error))
      }
    }
  }

  func cancel() {
    task?.cancel()
    task = nil
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
