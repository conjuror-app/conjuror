import Foundation

struct EmojiRanker {
  struct Index {
    private let emoji: [SearchableEmoji]

    init(emoji: [Emoji]) {
      self.emoji = emoji.map {
        SearchableEmoji(
          emoji: $0,
          normalizedName: EmojiRanker.normalized($0.name),
          tokens: EmojiRanker.tokens(in: EmojiRanker.normalized($0.name))
        )
      }
    }

    func ranked(query: String) -> [Emoji] {
      let query = EmojiRanker.normalized(query)
      guard !query.isEmpty else { return emoji.map(\.emoji) }
      let queryTokens = EmojiRanker.tokens(in: query)

      return emoji.compactMap { candidate -> (Emoji, Int)? in
        let score: Int
        if candidate.normalizedName == query {
          score = 0
        } else if candidate.normalizedName.hasPrefix(query) {
          score = 1
        } else if queryTokens.allSatisfy({ queryToken in
          candidate.tokens.contains(where: { $0.hasPrefix(queryToken) })
        }) {
          score = 2
        } else if candidate.normalizedName.contains(query) {
          score = 3
        } else {
          return nil
        }
        return (candidate.emoji, score)
      }
      .sorted {
        $0.1 == $1.1 ? $0.0.name < $1.0.name : $0.1 < $1.1
      }
      .map(\.0)
    }
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
  let emoji: Emoji
  let normalizedName: String
  let tokens: [String]
}
