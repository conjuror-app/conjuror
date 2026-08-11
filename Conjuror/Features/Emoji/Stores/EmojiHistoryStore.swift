import Foundation

struct EmojiHistoryStore {
  private static let storageKey = "recentEmoji"
  private static let limit = 30

  private let userDefaults: UserDefaults

  init(userDefaults: UserDefaults = .standard) {
    self.userDefaults = userDefaults
  }

  func load() -> [String] {
    Array((userDefaults.stringArray(forKey: Self.storageKey) ?? []).prefix(Self.limit))
  }

  func record(_ emoji: Emoji) {
    var values = load().filter { $0 != emoji.value }
    values.insert(emoji.value, at: 0)
    userDefaults.set(Array(values.prefix(Self.limit)), forKey: Self.storageKey)
  }
}
