import Foundation

struct Emoji: Identifiable, Hashable, Sendable {
  static let catalog: [Emoji] = {
    let url = Bundle.main.url(forResource: "EmojiCatalog", withExtension: "data")!
    let compressed = try! Data(contentsOf: url) as NSData
    let data = try! compressed.decompressed(using: .zlib) as Data
    let raw = String(decoding: data, as: UTF8.self)

    return raw.split(separator: "\n").compactMap { line -> Emoji? in
      let fields = line.split(separator: "|", maxSplits: 3, omittingEmptySubsequences: false)

      guard fields.count == 4 else { return nil }

      return Emoji(
        value: String(fields[0]),
        name: String(fields[1]),
        category: String(fields[2]),
        keywords: fields[3].split(separator: ",").map(String.init)
      )
    }
  }()

  static let byValue = Dictionary(uniqueKeysWithValues: catalog.map { ($0.value, $0) })

  /// Single-modifier variants keyed by base name and skin-tone modifier.
  private static let skinToneVariants = Dictionary(
    uniqueKeysWithValues: catalog.compactMap { emoji -> (String, Emoji)? in
      guard emoji.skinTones.count == 1, let modifierName = emoji.skinTones.first else {
        return nil
      }

      return (skinToneKey(baseName: emoji.baseName, modifierName: modifierName), emoji)
    }
  )

  /// Hides skin-tone variants and swaps in the preferred tone where one exists.
  static func withPreferredSkinTone(_ emoji: [Emoji], _ skinTone: EmojiSkinTone) -> [Emoji] {
    emoji.compactMap { emoji in
      guard !emoji.hasSkinTone else { return nil }

      guard let modifierName = skinTone.modifierName else { return emoji }

      return skinToneVariants[skinToneKey(baseName: emoji.name, modifierName: modifierName)]
        ?? emoji
    }
  }

  private static func skinToneKey(baseName: String, modifierName: String) -> String {
    "\(baseName)\0\(modifierName)"
  }

  let value: String
  let name: String
  let category: String
  let keywords: [String]

  var id: String { value }

  var baseName: String {
    guard let separator = name.range(of: ": ") else { return name }

    let descriptors = descriptors(after: separator)
    let baseDescriptors = descriptors.filter { !EmojiSkinTone.modifierNames.contains($0) }

    guard baseDescriptors.count != descriptors.count else { return name }

    let prefix = name[..<separator.lowerBound]

    return baseDescriptors.isEmpty
      ? String(prefix)
      : "\(prefix): \(baseDescriptors.joined(separator: ", "))"
  }

  var hasSkinTone: Bool { !skinTones.isEmpty }

  var skinTones: [String] {
    guard let separator = name.range(of: ": ") else { return [] }

    return descriptors(after: separator).filter(EmojiSkinTone.modifierNames.contains)
  }

  private func descriptors(after separator: Range<String.Index>) -> [String] {
    name[separator.upperBound...]
      .split(separator: ",")
      .map { $0.trimmingCharacters(in: .whitespaces) }
  }
}

enum EmojiSkinTone: String, CaseIterable, Identifiable, Sendable {
  case `default`
  case light
  case mediumLight
  case medium
  case mediumDark
  case dark

  static let modifierNames = allCases.compactMap(\.modifierName)

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
