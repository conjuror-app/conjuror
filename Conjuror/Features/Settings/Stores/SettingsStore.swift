import Combine
import Foundation

@MainActor
final class SettingsStore: ObservableObject {
  private struct HotKeyKeys {
    let code: String
    let displayName: String
    let modifiers: String
  }

  private enum Key {
    static let hotKeyCode = "settings.hotKeyCode"
    static let hotKeyDisplayName = "settings.hotKeyDisplayName"
    static let hotKeyModifiers = "settings.hotKeyModifiers"
    static let shortcutsHotKeyCode = "settings.shortcutsHotKeyCode"
    static let shortcutsHotKeyDisplayName = "settings.shortcutsHotKeyDisplayName"
    static let shortcutsHotKeyModifiers = "settings.shortcutsHotKeyModifiers"
    static let emojiHotKeyCode = "settings.emojiHotKeyCode"
    static let emojiHotKeyDisplayName = "settings.emojiHotKeyDisplayName"
    static let emojiHotKeyModifiers = "settings.emojiHotKeyModifiers"
    static let optionalHotKeysInitialized = "settings.optionalHotKeysInitialized"
    static let maximumVisibleResults = "settings.maximumVisibleResults"
    static let preferredEmojiSkinTone = "settings.preferredEmojiSkinTone"

    static func hotKeyKeys(for action: HotKeyAction) -> HotKeyKeys {
      switch action {
      case .launcher:
        HotKeyKeys(
          code: hotKeyCode,
          displayName: hotKeyDisplayName,
          modifiers: hotKeyModifiers
        )
      case .shortcuts:
        HotKeyKeys(
          code: shortcutsHotKeyCode,
          displayName: shortcutsHotKeyDisplayName,
          modifiers: shortcutsHotKeyModifiers
        )
      case .emoji:
        HotKeyKeys(
          code: emojiHotKeyCode,
          displayName: emojiHotKeyDisplayName,
          modifiers: emojiHotKeyModifiers
        )
      }
    }
  }

  nonisolated static let defaultMaximumVisibleResults = 7
  nonisolated static let maximumVisibleResultsRange = 3...10

  private static func clampedMaximumVisibleResults(_ value: Int) -> Int {
    min(
      max(value, maximumVisibleResultsRange.lowerBound),
      maximumVisibleResultsRange.upperBound
    )
  }

  private static func loadOptionalHotKey(
    from userDefaults: UserDefaults,
    keys: HotKeyKeys
  ) -> HotKeyConfiguration? {
    guard userDefaults.object(forKey: keys.code) != nil,
      userDefaults.object(forKey: keys.modifiers) != nil,
      let displayName = userDefaults.string(forKey: keys.displayName)
    else { return nil }
    return HotKeyConfiguration(
      keyCode: UInt32(userDefaults.integer(forKey: keys.code)),
      modifiers: UInt32(userDefaults.integer(forKey: keys.modifiers)),
      displayName: displayName
    )
  }

  @Published private(set) var hotKeyConfiguration: HotKeyConfiguration
  @Published private(set) var shortcutsHotKeyConfiguration: HotKeyConfiguration?
  @Published private(set) var emojiHotKeyConfiguration: HotKeyConfiguration?
  @Published private(set) var maximumVisibleResults: Int
  @Published private(set) var preferredEmojiSkinTone: EmojiSkinTone

  private let userDefaults: UserDefaults

  init(userDefaults: UserDefaults = .standard) {
    self.userDefaults = userDefaults

    if userDefaults.object(forKey: Key.hotKeyCode) != nil,
      userDefaults.object(forKey: Key.hotKeyModifiers) != nil,
      let displayName = userDefaults.string(forKey: Key.hotKeyDisplayName)
    {
      hotKeyConfiguration = HotKeyConfiguration(
        keyCode: UInt32(userDefaults.integer(forKey: Key.hotKeyCode)),
        modifiers: UInt32(userDefaults.integer(forKey: Key.hotKeyModifiers)),
        displayName: displayName
      )
    } else {
      hotKeyConfiguration = .defaultValue
    }

    let optionalHotKeysInitialized = userDefaults.bool(forKey: Key.optionalHotKeysInitialized)
    shortcutsHotKeyConfiguration =
      Self.loadOptionalHotKey(
        from: userDefaults,
        keys: Key.hotKeyKeys(for: .shortcuts)
      ) ?? (optionalHotKeysInitialized ? nil : HotKeyAction.shortcuts.defaultConfiguration)
    emojiHotKeyConfiguration =
      Self.loadOptionalHotKey(
        from: userDefaults,
        keys: Key.hotKeyKeys(for: .emoji)
      ) ?? (optionalHotKeysInitialized ? nil : HotKeyAction.emoji.defaultConfiguration)
    let storedMaximum =
      userDefaults.object(forKey: Key.maximumVisibleResults)
      .map { _ in userDefaults.integer(forKey: Key.maximumVisibleResults) }
      ?? Self.defaultMaximumVisibleResults
    maximumVisibleResults = Self.clampedMaximumVisibleResults(storedMaximum)
    preferredEmojiSkinTone =
      userDefaults.string(forKey: Key.preferredEmojiSkinTone)
      .flatMap(EmojiSkinTone.init(rawValue:)) ?? .default

    if !optionalHotKeysInitialized {
      userDefaults.set(true, forKey: Key.optionalHotKeysInitialized)
      persistOptionalHotKey(shortcutsHotKeyConfiguration, for: .shortcuts)
      persistOptionalHotKey(emojiHotKeyConfiguration, for: .emoji)
    }
  }

  func hotKeyConfiguration(for action: HotKeyAction) -> HotKeyConfiguration? {
    switch action {
    case .launcher: hotKeyConfiguration
    case .shortcuts: shortcutsHotKeyConfiguration
    case .emoji: emojiHotKeyConfiguration
    }
  }

  func setHotKeyConfiguration(
    _ configuration: HotKeyConfiguration?,
    for action: HotKeyAction = .launcher
  ) {
    switch action {
    case .launcher:
      guard let configuration else { return }
      hotKeyConfiguration = configuration
      userDefaults.set(Int(configuration.keyCode), forKey: Key.hotKeyCode)
      userDefaults.set(Int(configuration.modifiers), forKey: Key.hotKeyModifiers)
      userDefaults.set(configuration.displayName, forKey: Key.hotKeyDisplayName)
    case .shortcuts:
      shortcutsHotKeyConfiguration = configuration
      persistOptionalHotKey(configuration, for: action)
    case .emoji:
      emojiHotKeyConfiguration = configuration
      persistOptionalHotKey(configuration, for: action)
    }
  }

  func setMaximumVisibleResults(_ value: Int) {
    let clampedValue = Self.clampedMaximumVisibleResults(value)
    maximumVisibleResults = clampedValue
    userDefaults.set(clampedValue, forKey: Key.maximumVisibleResults)
  }

  func setPreferredEmojiSkinTone(_ skinTone: EmojiSkinTone) {
    preferredEmojiSkinTone = skinTone
    userDefaults.set(skinTone.rawValue, forKey: Key.preferredEmojiSkinTone)
  }

  func resetMaximumVisibleResults() {
    setMaximumVisibleResults(Self.defaultMaximumVisibleResults)
  }

  private func persistOptionalHotKey(
    _ configuration: HotKeyConfiguration?,
    for action: HotKeyAction
  ) {
    let keys = Key.hotKeyKeys(for: action)
    guard let configuration else {
      userDefaults.removeObject(forKey: keys.code)
      userDefaults.removeObject(forKey: keys.modifiers)
      userDefaults.removeObject(forKey: keys.displayName)
      return
    }
    userDefaults.set(Int(configuration.keyCode), forKey: keys.code)
    userDefaults.set(Int(configuration.modifiers), forKey: keys.modifiers)
    userDefaults.set(configuration.displayName, forKey: keys.displayName)
  }
}
