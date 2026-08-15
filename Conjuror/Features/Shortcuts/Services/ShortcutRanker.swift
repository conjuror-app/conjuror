import Foundation

struct ShortcutRanker {
  struct Index {
    private let index: SearchIndex<AppleShortcut>

    init(shortcuts: [AppleShortcut]) {
      index = SearchIndex(
        candidates: shortcuts.map { shortcut in
          SearchIndex.Candidate(
            item: shortcut,
            name: shortcut.name,
            secondaryText: shortcut.subtitle,
            recencyKey: shortcut.persistenceKey,
            stableKey: shortcut.id
          )
        }
      )
    }

    func ranked(
      query: String,
      recentRuns: [String: Date]
    ) -> [AppleShortcut] {
      index.ranked(query: query, recency: recentRuns)
    }
  }

  static func ranked(
    shortcuts: [AppleShortcut],
    query: String,
    recentRuns: [String: Date]
  ) -> [AppleShortcut] {
    Index(shortcuts: shortcuts).ranked(query: query, recentRuns: recentRuns)
  }
}
