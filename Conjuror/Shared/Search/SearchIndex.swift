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

    if lhs.candidate.name.normalized != rhs.candidate.name.normalized {
      return lhs.candidate.name.normalized < rhs.candidate.name.normalized
    }

    return lhs.candidate.stableKey < rhs.candidate.stableKey
  }

  private let items: [Item]
  private let candidates: [SearchableCandidate]

  /// `aliases` maps a candidate's `recencyKey` to an alias typed in place of its name.
  init(candidates: [Candidate], aliases: [String: String] = [:]) {
    items = candidates.map(\.item)
    self.candidates = candidates.enumerated().map { index, candidate in
      SearchableCandidate(
        itemIndex: index,
        name: SearchableName(candidate.name),
        normalizedSecondaryText: SearchText.normalized(candidate.secondaryText),
        normalizedAlias: aliases[candidate.recencyKey].map(SearchText.normalized),
        recencyKey: candidate.recencyKey,
        fallbackRecencyKey: candidate.fallbackRecencyKey,
        stableKey: candidate.stableKey
      )
    }
  }

  /// Matches ranked best first. `maximumCategory` drops weaker matches, such as fuzzy ones.
  func ranked(query: String, recency: [String: Date], maximumCategory: Int? = nil) -> [Item] {
    let query = SearchQuery(query)

    return candidates.compactMap { candidate -> RankedCandidate? in
      let nameRank = candidate.name.matchRank(
        for: query,
        normalizedSecondaryText: candidate.normalizedSecondaryText
      )
      let aliasRank = candidate.normalizedAlias.flatMap { query.aliasRank(for: $0) }

      guard let rank = [nameRank, aliasRank].compactMap({ $0 }).min(),
        rank.category <= maximumCategory ?? .max
      else { return nil }

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

extension SearchIndex where Item: SearchIndexable {
  init(_ items: [Item], aliases: [String: String] = [:]) {
    self.init(candidates: items.map(\.searchCandidate), aliases: aliases)
  }
}

private extension SearchIndex {
  struct SearchableCandidate {
    let itemIndex: Int
    let name: SearchableName
    let normalizedSecondaryText: String
    let normalizedAlias: String?
    let recencyKey: String
    let fallbackRecencyKey: String?
    let stableKey: String
  }

  struct RankedCandidate {
    let candidate: SearchableCandidate
    let rank: SearchMatchRank
    let lastUse: Date?
  }
}

/// An item that describes how it is matched and ranked in a `SearchIndex`.
protocol SearchIndexable {
  var searchCandidate: SearchIndex<Self>.Candidate { get }
}

/// Precomputed forms of a name, matched against a query.
struct SearchableName {
  /// Runs the same name match used for ranking and maps its positions back to the display name.
  static func matchingRanges(
    in name: String,
    query: SearchQuery,
    secondaryText: String = "",
    alias: String? = nil
  ) -> [Range<String.Index>] {
    guard !query.normalized.isEmpty else { return [] }

    let searchableName = Self(name)
    var positions = [Int]()
    guard
      let rank = searchableName.matchRank(
        for: query,
        normalizedSecondaryText: SearchText.normalized(secondaryText),
        onNameMatch: { positions = $0 }
      ), !positions.isEmpty
    else { return [] }

    if let alias, let aliasRank = query.aliasRank(for: SearchText.normalized(alias)),
      aliasRank < rank
    {
      return []
    }

    let displayIndices = SearchText.displayIndices(in: name)
    let matched = Set(
      positions.compactMap { position in
        displayIndices.indices.contains(position) ? displayIndices[position] : nil
      }
    )

    var ranges = [Range<String.Index>]()
    for index in name.indices where matched.contains(index) {
      let end = name.index(after: index)
      if let last = ranges.last, last.upperBound == index {
        ranges[ranges.count - 1] = last.lowerBound..<end
      } else {
        ranges.append(index..<end)
      }
    }
    return ranges
  }

  let normalized: String
  private let tokens: [Substring]
  private let compact: String
  private let acronym: String

  init(_ name: String) {
    normalized = SearchText.normalized(name)
    tokens = normalized.split(whereSeparator: { !$0.isLetter && !$0.isNumber })
    compact = tokens.joined()
    acronym = String(tokens.compactMap(\.first))
  }

  func matchRank(
    for query: SearchQuery,
    normalizedSecondaryText: String = "",
    onNameMatch: (([Int]) -> Void)? = nil
  ) -> SearchMatchRank? {
    func rank(_ category: Int, positions: @autoclosure () -> [Int]) -> SearchMatchRank {
      onNameMatch?(positions())
      return SearchMatchRank(category: category)
    }

    guard !query.normalized.isEmpty else { return SearchMatchRank(category: 6) }

    if normalized == query.normalized {
      return rank(0, positions: Array(0..<normalized.count))
    }

    if normalized.hasPrefix(query.normalized) {
      return rank(1, positions: Array(0..<query.normalized.count))
    }

    if !query.tokens.isEmpty,
      query.tokens.allSatisfy({ token in
        tokens.contains(where: { $0.hasPrefix(token) })
      })
    {
      return rank(2, positions: tokenPrefixPositions(for: query.tokens))
    }

    if !query.compact.isEmpty, acronym.hasPrefix(query.compact) {
      return rank(
        3,
        positions: tokens.prefix(query.compact.count).map { offset(of: $0.startIndex) }
      )
    }

    if let range = normalized.range(of: query.normalized) {
      return rank(4, positions: Array(offset(of: range.lowerBound)..<offset(of: range.upperBound)))
    }

    if let range = compact.range(of: query.compact) {
      let start = compact.distance(from: compact.startIndex, to: range.lowerBound)
      let length = compact.distance(from: range.lowerBound, to: range.upperBound)
      return rank(4, positions: Array(compactPositions.dropFirst(start).prefix(length)))
    }

    if normalizedSecondaryText.contains(query.normalized) {
      return SearchMatchRank(category: 4)
    }

    if let score = fuzzyScore(for: query, onNameMatch: onNameMatch) {
      return SearchMatchRank(category: 5, score: score)
    }

    return nil
  }

  private var compactPositions: [Int] {
    tokens.flatMap { token in
      let start = offset(of: token.startIndex)
      return start..<(start + token.count)
    }
  }

  private func fuzzyScore(for query: SearchQuery, onNameMatch: (([Int]) -> Void)?) -> Int? {
    guard let onNameMatch else {
      return SearchText.subsequenceScore(of: query.compact, in: compact)
    }

    var positions = [Int]()
    guard
      let score = SearchText.subsequenceScore(
        of: query.compact,
        in: compact,
        onMatch: { positions.append($0) }
      )
    else { return nil }

    let offsets = compactPositions
    onNameMatch(positions.map { offsets[$0] })
    return score
  }

  private func offset(of index: String.Index) -> Int {
    normalized.distance(from: normalized.startIndex, to: index)
  }

  private func tokenPrefixPositions(for prefixes: [String]) -> [Int] {
    prefixes.flatMap { prefix -> Range<Int> in
      guard let token = tokens.first(where: { $0.hasPrefix(prefix) }) else { return 0..<0 }
      let start = offset(of: token.startIndex)
      return start..<(start + prefix.count)
    }
  }
}

enum SearchText {
  static func normalized(_ value: String) -> String {
    folded(value)
      .split(whereSeparator: { $0.isWhitespace })
      .joined(separator: " ")
  }

  static func tokens(in value: String) -> [String] {
    value.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init)
  }

  /// Each normalized character points to the original grapheme, including expanded folds.
  static func displayIndices(in value: String) -> [String.Index] {
    var indices = [String.Index]()
    var whitespace: String.Index?
    for index in value.indices {
      for character in folded(String(value[index])) {
        if character.isWhitespace {
          if whitespace == nil { whitespace = index }
        } else {
          if let whitespace, !indices.isEmpty { indices.append(whitespace) }
          whitespace = nil
          indices.append(index)
        }
      }
    }
    return indices
  }

  static func subsequenceScore(
    of query: String,
    in target: String,
    onMatch: ((Int) -> Void)? = nil
  ) -> Int? {
    guard !query.isEmpty else { return nil }

    var firstPosition: Int?
    var lastPosition = 0
    var matchedCount = 0
    var targetCharacters = target.enumerated().makeIterator()
    for queryCharacter in query {
      var matchedPosition: Int?
      while let (position, character) = targetCharacters.next() {
        if character == queryCharacter {
          matchedPosition = position
          break
        }
      }
      guard let matchedPosition else { return nil }

      firstPosition = firstPosition ?? matchedPosition
      lastPosition = matchedPosition
      matchedCount += 1
      onMatch?(matchedPosition)
    }

    guard let firstPosition else { return nil }
    return (lastPosition - firstPosition + 1 - matchedCount) * 1_000 + firstPosition
  }

  private static func folded(_ value: String) -> String {
    value
      .folding(
        options: [.caseInsensitive, .diacriticInsensitive],
        locale: Locale(identifier: "en_US_POSIX")
      )
      .lowercased()
  }
}

struct SearchQuery {
  let normalized: String
  let tokens: [String]
  let compact: String

  init(_ value: String) {
    normalized = SearchText.normalized(value)
    tokens = SearchText.tokens(in: normalized)
    compact = tokens.joined()
  }

  /// An exact alias ranks above every name match. A partial alias ranks as a name prefix.
  func aliasRank(for normalizedAlias: String) -> SearchMatchRank? {
    guard !normalized.isEmpty else { return nil }
    if normalizedAlias == normalized { return .alias }
    return normalizedAlias.hasPrefix(normalized) ? SearchMatchRank(category: 1) : nil
  }
}

struct SearchMatchRank: Equatable, Comparable {
  static let unmatched = SearchMatchRank(category: .max)
  /// An exact alias match, ranked above an exact name match.
  static let alias = SearchMatchRank(category: -1)

  static func < (lhs: SearchMatchRank, rhs: SearchMatchRank) -> Bool {
    lhs.category == rhs.category ? lhs.score < rhs.score : lhs.category < rhs.category
  }

  let category: Int
  var score = 0
}
