import Foundation

struct SearchIndex<Item> {
  struct Candidate {
    let item: Item
    let name: String
    let secondaryText: String
    let recencyKey: String
    let stableKey: String

    init(
      item: Item,
      name: String,
      secondaryText: String = "",
      recencyKey: String,
      stableKey: String
    ) {
      self.item = item
      self.name = name
      self.secondaryText = secondaryText
      self.recencyKey = recencyKey
      self.stableKey = stableKey
    }
  }

  private let candidates: [SearchableCandidate]

  init(candidates: [Candidate]) {
    self.candidates = candidates.map { candidate in
      let normalizedName = SearchText.normalized(candidate.name)
      let nameTokens = SearchText.tokens(in: normalizedName)
      return SearchableCandidate(
        candidate: candidate,
        normalizedName: normalizedName,
        normalizedSecondaryText: SearchText.normalized(candidate.secondaryText),
        nameTokens: nameTokens,
        compactName: nameTokens.joined()
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
        lastUse: recency[candidate.candidate.recencyKey]
      )
    }
    .sorted(by: Self.areInIncreasingOrder)
    .map(\.candidate.candidate.item)
  }

  private static func areInIncreasingOrder(
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
    return lhs.candidate.candidate.stableKey < rhs.candidate.candidate.stableKey
  }
}

private extension SearchIndex {
  struct SearchableCandidate {
    let candidate: Candidate
    let normalizedName: String
    let normalizedSecondaryText: String
    let nameTokens: [String]
    let compactName: String

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
      let acronym = nameTokens.compactMap(\.first).map(String.init).joined()
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
    let queryCharacters = Array(query)
    let targetCharacters = Array(target)
    var firstPosition: Int?
    var lastPosition: Int?
    var searchStart = 0

    for character in queryCharacters {
      guard searchStart < targetCharacters.count,
        let position = targetCharacters[searchStart...].firstIndex(of: character)
      else { return nil }
      firstPosition = firstPosition ?? position
      lastPosition = position
      searchStart = position + 1
    }

    guard let firstPosition, let lastPosition else { return nil }
    return (lastPosition - firstPosition + 1 - queryCharacters.count) * 1_000 + firstPosition
  }
}
