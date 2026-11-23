import Foundation

struct QuicklinkMatcher {
  struct Match: Equatable {
    let quicklink: Quicklink
    let argument: String
  }

  static let maximumNameMatches = 3

  private static let maximumNameMatchCategory = 4

  private let quicklinksByKeyword: [String: Quicklink]
  private let index: SearchIndex<Quicklink>

  init(quicklinks: [Quicklink]) {
    quicklinksByKeyword = Dictionary(
      quicklinks.compactMap { quicklink in quicklink.keyword.map { ($0.lowercased(), quicklink) } },
      uniquingKeysWith: { first, _ in first }
    )
    index = SearchIndex(quicklinks)
  }

  func keywordMatch(for query: String) -> Match? {
    let query = query.drop(while: \.isWhitespace)
    let keywordEnd = query.firstIndex(where: \.isWhitespace) ?? query.endIndex

    guard !query.isEmpty,
      let quicklink = quicklinksByKeyword[query[..<keywordEnd].lowercased()]
    else { return nil }

    return Match(
      quicklink: quicklink,
      argument: query[keywordEnd...].trimmingCharacters(in: .whitespacesAndNewlines)
    )
  }

  func nameMatches(
    for query: String,
    recency: [String: Date],
    excluding excludedID: Quicklink.ID? = nil
  ) -> [Quicklink] {
    guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return [] }

    return Array(
      index.ranked(query: query, recency: recency, maximumCategory: Self.maximumNameMatchCategory)
        .lazy
        .filter { $0.id != excludedID }
        .prefix(Self.maximumNameMatches)
    )
  }
}
