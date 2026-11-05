import Foundation

/// A searchable catalog ranked by recorded uses.
final class RankedCatalog<Item: SearchIndexable> {
  private let history: RecencyStore
  private var index: SearchIndex<Item>
  private var recentUses: [String: Date]

  init(history: RecencyStore) {
    self.history = history
    index = SearchIndex([])
    recentUses = history.load()
  }

  func replace(_ items: [Item]) {
    index = SearchIndex(items)
  }

  func ranked(query: String) -> [Item] {
    index.ranked(query: query, recency: recentUses)
  }

  func record(key: String) {
    recentUses = history.record(key: key)
  }

  /// Reloads uses recorded through another catalog that shares this history.
  func reloadHistory() {
    recentUses = history.load()
  }
}
