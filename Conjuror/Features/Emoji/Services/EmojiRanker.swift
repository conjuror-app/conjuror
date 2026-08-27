import Foundation

struct EmojiRanker {
  struct Index {
    private let emoji: [Emoji]
    private let searchableEmoji: [SearchableEmoji]

    init(emoji: [Emoji]) {
      self.emoji = emoji
      searchableEmoji = emoji.enumerated().map { index, emoji in
        let normalizedName = EmojiRanker.normalized(emoji.name)
        let normalizedKeywords = emoji.keywords.map(EmojiRanker.normalized)
        return SearchableEmoji(
          emojiIndex: index,
          normalizedName: normalizedName,
          searchableText: ([normalizedName] + normalizedKeywords).joined(separator: " "),
          tokens: ([normalizedName] + normalizedKeywords).flatMap(EmojiRanker.tokens)
        )
      }
    }

    func ranked(query: String) -> [Emoji] {
      let query = EmojiRanker.normalized(query)
      guard !query.isEmpty else { return emoji }
      let queryTokens = EmojiRanker.tokens(in: query)

      return searchableEmoji.compactMap { candidate -> (Int, Int)? in
        let score: Int
        if candidate.normalizedName == query {
          score = 0
        } else if candidate.normalizedName.hasPrefix(query) {
          score = 1
        } else if queryTokens.allSatisfy({ queryToken in
          candidate.tokens.contains(where: { $0.hasPrefix(queryToken) })
        }) {
          score = 2
        } else if candidate.searchableText.contains(query) {
          score = 3
        } else {
          return nil
        }
        return (candidate.emojiIndex, score)
      }
      .sorted {
        $0.1 == $1.1 ? emoji[$0.0].name < emoji[$1.0].name : $0.1 < $1.1
      }
      .map { emoji[$0.0] }
    }
  }

  static func explicitlyRequestsSkinTone(_ query: String) -> Bool {
    let query = normalized(query)
    return query.contains("skin tone") || query.contains("light")
      || query.contains("medium") || query.contains("dark")
  }

  private static func normalized(_ value: String) -> String {
    value.folding(
      options: [.caseInsensitive, .diacriticInsensitive],
      locale: Locale(identifier: "en_US_POSIX")
    )
    .lowercased()
    .replacingOccurrences(of: "_", with: " ")
    .replacingOccurrences(of: "-", with: " ")
    .split(whereSeparator: { $0.isWhitespace })
    .joined(separator: " ")
  }

  private static func tokens(in value: String) -> [String] {
    value.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init)
  }
}

private struct SearchableEmoji {
  let emojiIndex: Int
  let normalizedName: String
  let searchableText: String
  let tokens: [String]
}
