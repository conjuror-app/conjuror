import Foundation

struct SearchIndex<Item> {
  struct Candidate {
    let item: Item
    let name: String
    let secondaryText: String
    let recencyKey: String
    /// Recency key used until `recencyKey` has its own recorded use.
    let fallbackRecencyKey: String?
    let stableKey: String

    init(
      item: Item,
      name: String,
      secondaryText: String = "",
      recencyKey: String,
      fallbackRecencyKey: String? = nil,
      stableKey: String
    ) {
      self.item = item
      self.name = name
      self.secondaryText = secondaryText
      self.recencyKey = recencyKey
      self.fallbackRecencyKey = fallbackRecencyKey
      self.stableKey = stableKey
    }
  }

  private static func rankOrder(
    _ lhs: RankedCandidate,
    _ rhs: RankedCandidate
  ) -> Bool {
    if lhs.rank != rhs.rank { return lhs.rank < rhs.rank }

    if lhs.lastUse != rhs.lastUse {
      return (lhs.lastUse ?? .distantPast) > (rhs.lastUse ?? .distantPast)
    }

    if lhs.candidate.normalizedName != rhs.candidate.normalizedName {
      return lhs.candidate.normalizedName < rhs.candidate.normalizedName
    }

    return lhs.candidate.stableKey < rhs.candidate.stableKey
  }

  private let items: [Item]
  private let candidates: [SearchableCandidate]

  init(candidates: [Candidate]) {
    items = candidates.map(\.item)
    self.candidates = candidates.enumerated().map { index, candidate in
      let normalizedName = SearchText.normalized(candidate.name)
      let nameTokens = SearchText.tokens(in: normalizedName)

      return SearchableCandidate(
        itemIndex: index,
        normalizedName: normalizedName,
        normalizedSecondaryText: SearchText.normalized(candidate.secondaryText),
        nameTokens: nameTokens,
        compactName: nameTokens.joined(),
        acronym: String(nameTokens.compactMap(\.first)),
        recencyKey: candidate.recencyKey,
        fallbackRecencyKey: candidate.fallbackRecencyKey,
        stableKey: candidate.stableKey
      )
    }
  }

  func ranked(query: String, recency: [String: Date]) -> [Item] {
    let query = SearchQuery(query)

    return candidates.compactMap { candidate -> RankedCandidate? in
      guard let rank = candidate.matchRank(for: query) else { return nil }

      return RankedCandidate(
        candidate: candidate,
        rank: rank,
        lastUse: recency[candidate.recencyKey]
          ?? candidate.fallbackRecencyKey.flatMap { recency[$0] }
      )
    }
    .sorted(by: Self.rankOrder)
    .map { items[$0.candidate.itemIndex] }
  }
}

private extension SearchIndex {
  struct SearchableCandidate {
    let itemIndex: Int
    let normalizedName: String
    let normalizedSecondaryText: String
    let nameTokens: [String]
    let compactName: String
    let acronym: String
    let recencyKey: String
    let fallbackRecencyKey: String?
    let stableKey: String

    func matchRank(for query: SearchQuery) -> SearchMatchRank? {
      guard !query.normalized.isEmpty else { return SearchMatchRank(category: 6) }

      if normalizedName == query.normalized { return SearchMatchRank(category: 0) }

      if normalizedName.hasPrefix(query.normalized) { return SearchMatchRank(category: 1) }

      if !query.tokens.isEmpty,
        query.tokens.allSatisfy({ token in
          nameTokens.contains(where: { $0.hasPrefix(token) })
        })
      {
        return SearchMatchRank(category: 2)
      }

      if !query.compact.isEmpty, acronym.hasPrefix(query.compact) {
        return SearchMatchRank(category: 3)
      }

      if normalizedName.contains(query.normalized)
        || compactName.contains(query.compact)
        || normalizedSecondaryText.contains(query.normalized)
      {
        return SearchMatchRank(category: 4)
      }

      if let score = SearchText.subsequenceScore(of: query.compact, in: compactName) {
        return SearchMatchRank(category: 5, score: score)
      }

      return nil
    }
  }

  struct RankedCandidate {
    let candidate: SearchableCandidate
    let rank: SearchMatchRank
    let lastUse: Date?
  }
}

enum SearchText {
  static func normalized(_ value: String) -> String {
    value
      .folding(
        options: [.caseInsensitive, .diacriticInsensitive],
        locale: Locale(identifier: "en_US_POSIX")
      )
      .lowercased()
      .split(whereSeparator: { $0.isWhitespace })
      .joined(separator: " ")
  }

  static func tokens(in value: String) -> [String] {
    value.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init)
  }

  static func subsequenceScore(of query: String, in target: String) -> Int? {
    guard !query.isEmpty else { return nil }

    var firstPosition: Int?
    var lastPosition: Int?
    var targetIndex = target.startIndex
    var targetPosition = 0
    var matchedCount = 0

    for queryCharacter in query {
      var matchedPosition: Int?

      while targetIndex < target.endIndex {
        let targetCharacter = target[targetIndex]
        target.formIndex(after: &targetIndex)
        defer { targetPosition += 1 }

        if targetCharacter == queryCharacter {
          matchedPosition = targetPosition
          break
        }
      }

      guard let matchedPosition else { return nil }

      firstPosition = firstPosition ?? matchedPosition
      lastPosition = matchedPosition
      matchedCount += 1
    }

    guard let firstPosition, let lastPosition else { return nil }

    return (lastPosition - firstPosition + 1 - matchedCount) * 1_000 + firstPosition
  }
}

private struct SearchQuery {
  let normalized: String
  let tokens: [String]
  let compact: String

  init(_ value: String) {
    normalized = SearchText.normalized(value)
    tokens = SearchText.tokens(in: normalized)
    compact = tokens.joined()
  }
}

private struct SearchMatchRank: Equatable, Comparable {
  static func < (lhs: SearchMatchRank, rhs: SearchMatchRank) -> Bool {
    lhs.category == rhs.category ? lhs.score < rhs.score : lhs.category < rhs.category
  }

  let category: Int
  var score = 0
}
