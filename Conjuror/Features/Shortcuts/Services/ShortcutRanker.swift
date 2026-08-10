import Foundation

private typealias MatchRank = ShortcutMatchRank

struct ShortcutRanker {
  struct Index {
    private let shortcuts: [SearchableShortcut]

    init(shortcuts: [AppleShortcut]) {
      self.shortcuts = shortcuts.map { shortcut in
        let normalizedName = normalized(shortcut.name)
        let nameTokens = tokens(in: normalizedName)
        return SearchableShortcut(
          shortcut: shortcut,
          normalizedName: normalizedName,
          normalizedSubtitle: normalized(shortcut.subtitle),
          nameTokens: nameTokens,
          compactName: nameTokens.joined()
        )
      }
    }

    func ranked(
      query: String,
      recentRuns: [String: Date]
    ) -> [AppleShortcut] {
      let normalizedQuery = normalized(query)
      let queryTokens = tokens(in: normalizedQuery)
      let matchQuery = MatchQuery(
        normalized: normalizedQuery,
        tokens: queryTokens,
        compact: queryTokens.joined()
      )

      return
        shortcuts
        .compactMap { shortcut -> RankedShortcut? in
          guard let matchRank = matchRank(shortcut: shortcut, query: matchQuery) else {
            return nil
          }
          return RankedShortcut(
            searchableShortcut: shortcut,
            matchRank: matchRank,
            lastRun: recentRuns[shortcut.shortcut.persistenceKey]
          )
        }
        .sorted(by: rankedShortcutOrder)
        .map(\.searchableShortcut.shortcut)
    }
  }

  static func ranked(
    shortcuts: [AppleShortcut],
    query: String,
    recentRuns: [String: Date]
  ) -> [AppleShortcut] {
    Index(shortcuts: shortcuts).ranked(query: query, recentRuns: recentRuns)
  }

  private static func normalized(_ value: String) -> String {
    value
      .folding(
        options: [.caseInsensitive, .diacriticInsensitive],
        locale: Locale(identifier: "en_US_POSIX")
      )
      .lowercased()
      .split(whereSeparator: { $0.isWhitespace })
      .joined(separator: " ")
  }

  private static func matchRank(
    shortcut: SearchableShortcut,
    query: MatchQuery
  ) -> MatchRank? {
    guard !query.normalized.isEmpty else {
      return MatchRank(category: 6)
    }
    if shortcut.normalizedName == query.normalized {
      return MatchRank(category: 0)
    }
    if shortcut.normalizedName.hasPrefix(query.normalized) {
      return MatchRank(category: 1)
    }
    if !query.tokens.isEmpty,
      query.tokens.allSatisfy({ queryToken in
        shortcut.nameTokens.contains(where: { $0.hasPrefix(queryToken) })
      })
    {
      return MatchRank(category: 2)
    }

    let acronym = shortcut.nameTokens.compactMap(\.first).map(String.init).joined()
    if !query.compact.isEmpty, acronym.hasPrefix(query.compact) {
      return MatchRank(category: 3)
    }
    if shortcut.normalizedName.contains(query.normalized)
      || shortcut.compactName.contains(query.compact)
      || shortcut.normalizedSubtitle.contains(query.normalized)
    {
      return MatchRank(category: 4)
    }
    if let score = subsequenceScore(of: query.compact, in: shortcut.compactName) {
      return MatchRank(category: 5, score: score)
    }
    return nil
  }

  private static func tokens(in value: String) -> [String] {
    value.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init)
  }

  private static func subsequenceScore(of query: String, in target: String) -> Int? {
    guard !query.isEmpty else {
      return nil
    }

    let queryCharacters = Array(query)
    let targetCharacters = Array(target)
    var matchedPositions = [Int]()
    var searchStart = 0

    for queryCharacter in queryCharacters {
      guard searchStart < targetCharacters.count,
        let position = targetCharacters[searchStart...].firstIndex(of: queryCharacter)
      else {
        return nil
      }
      matchedPositions.append(position)
      searchStart = position + 1
    }

    guard let firstPosition = matchedPositions.first,
      let lastPosition = matchedPositions.last
    else {
      return nil
    }
    let skippedCharacters = lastPosition - firstPosition + 1 - queryCharacters.count
    return skippedCharacters * 1_000 + firstPosition
  }

  private static func rankedShortcutOrder(
    _ lhs: RankedShortcut,
    _ rhs: RankedShortcut
  ) -> Bool {
    if lhs.matchRank != rhs.matchRank {
      return lhs.matchRank < rhs.matchRank
    }
    if lhs.lastRun != rhs.lastRun {
      return (lhs.lastRun ?? .distantPast) > (rhs.lastRun ?? .distantPast)
    }
    if lhs.searchableShortcut.normalizedName != rhs.searchableShortcut.normalizedName {
      return lhs.searchableShortcut.normalizedName < rhs.searchableShortcut.normalizedName
    }
    return lhs.searchableShortcut.shortcut.id < rhs.searchableShortcut.shortcut.id
  }
}

private struct ShortcutMatchRank: Equatable, Comparable {
  static func < (lhs: ShortcutMatchRank, rhs: ShortcutMatchRank) -> Bool {
    if lhs.category != rhs.category {
      return lhs.category < rhs.category
    }
    return lhs.score < rhs.score
  }

  let category: Int
  var score = 0
}

private struct RankedShortcut {
  let searchableShortcut: SearchableShortcut
  let matchRank: MatchRank
  let lastRun: Date?
}

private struct SearchableShortcut {
  let shortcut: AppleShortcut
  let normalizedName: String
  let normalizedSubtitle: String
  let nameTokens: [String]
  let compactName: String
}

private struct MatchQuery {
  let normalized: String
  let tokens: [String]
  let compact: String
}
