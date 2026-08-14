import Foundation

struct Emoji: Identifiable, Hashable, Sendable {
  static let catalog = EmojiData.raw.split(separator: "\n").compactMap { line -> Emoji? in
    let fields = line.split(separator: "|", maxSplits: 3, omittingEmptySubsequences: false)
    guard fields.count == 4 else { return nil }
    return Emoji(
      value: String(fields[0]),
      name: String(fields[1]),
      category: String(fields[2]),
      keywords: fields[3].split(separator: ",").map(String.init)
    )
  }

  let value: String
  let name: String
  let category: String
  let keywords: [String]

  var id: String { value }
  var persistenceKey: String { value }

  var baseName: String {
    guard let separator = name.range(of: ": ") else { return name }
    let descriptors = descriptorComponents(after: separator)
    let baseDescriptors = descriptors.filter { !EmojiSkinTone.modifierNames.contains($0) }
    guard baseDescriptors.count != descriptors.count else { return name }

    let prefix = name[..<separator.lowerBound]
    return baseDescriptors.isEmpty
      ? String(prefix)
      : "\(prefix): \(baseDescriptors.joined(separator: ", "))"
  }

  var hasSkinTone: Bool { !skinToneModifierNames.isEmpty }

  var skinToneModifierNames: [String] {
    guard let separator = name.range(of: ": ") else { return [] }
    return descriptorComponents(after: separator).filter(EmojiSkinTone.modifierNames.contains)
  }

  private func descriptorComponents(after separator: Range<String.Index>) -> [String] {
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

private enum EmojiData {
  static let raw: String = {
    let url = Bundle.main.url(forResource: "EmojiCatalog", withExtension: "data")!
    let compressed = try! Data(contentsOf: url) as NSData
    let data = try! compressed.decompressed(using: .zlib) as Data
    return String(decoding: data, as: UTF8.self)
  }()
}
