import Foundation

/// Finds history items containing every word of a query, keeping the newest first.
struct ClipboardSearchIndex {
  /// Long items are only searched near their start, so typing stays fast.
  private static let searchableLength = 10_000

  private let items: [ClipboardItem]
  private let normalizedTexts: [String]

  init(items: [ClipboardItem]) {
    self.items = items
    normalizedTexts = items.map {
      SearchText.normalized(String($0.text.prefix(Self.searchableLength)))
    }
  }

  func matches(for query: String) -> [ClipboardItem] {
    let words = SearchText.normalized(query).split(separator: " ")

    guard !words.isEmpty else { return items }

    return zip(items, normalizedTexts).compactMap { item, text in
      words.allSatisfy { text.contains($0) } ? item : nil
    }
  }
}
