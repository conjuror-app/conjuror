struct Emoji: Identifiable, Hashable, Sendable {
  static let catalog = EmojiData.raw.split(separator: "\n").compactMap { line -> Emoji? in
    let fields = line.split(separator: "|", maxSplits: 2, omittingEmptySubsequences: false)
    guard fields.count == 3 else { return nil }
    return Emoji(value: String(fields[0]), name: String(fields[1]), category: String(fields[2]))
  }

  let value: String
  let name: String
  let category: String

  var id: String { value }
  var persistenceKey: String { value }

  var baseName: String {
    guard let separator = name.range(of: ": "),
      EmojiSkinTone.allCases.dropFirst().contains(where: {
        guard let modifierName = $0.modifierName else { return false }
        return name[separator.upperBound...].hasPrefix(modifierName)
      })
    else { return name }
    return String(name[..<separator.lowerBound])
  }

  var hasSkinTone: Bool { baseName != name }
}

enum EmojiSkinTone: String, CaseIterable, Identifiable, Sendable {
  case `default`
  case light
  case mediumLight
  case medium
  case mediumDark
  case dark

  var id: String { rawValue }

  var displayName: String {
    switch self {
    case .default: "Default"
    case .light: "Light"
    case .mediumLight: "Medium-Light"
    case .medium: "Medium"
    case .mediumDark: "Medium-Dark"
    case .dark: "Dark"
    }
  }

  var exampleEmoji: String {
    switch self {
    case .default: "👋"
    case .light: "👋🏻"
    case .mediumLight: "👋🏼"
    case .medium: "👋🏽"
    case .mediumDark: "👋🏾"
    case .dark: "👋🏿"
    }
  }

  var modifierName: String? {
    switch self {
    case .default: nil
    case .light: "light skin tone"
    case .mediumLight: "medium-light skin tone"
    case .medium: "medium skin tone"
    case .mediumDark: "medium-dark skin tone"
    case .dark: "dark skin tone"
    }
  }
}
