import Combine
import Foundation

@MainActor
final class SettingsStore: ObservableObject {
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
    codeKey: String,
    modifiersKey: String,
    displayNameKey: String
  ) -> HotKeyConfiguration? {
    guard userDefaults.object(forKey: codeKey) != nil,
      userDefaults.object(forKey: modifiersKey) != nil,
      let displayName = userDefaults.string(forKey: displayNameKey)
    else { return nil }
    return HotKeyConfiguration(
      keyCode: UInt32(userDefaults.integer(forKey: codeKey)),
      modifiers: UInt32(userDefaults.integer(forKey: modifiersKey)),
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
        codeKey: Key.shortcutsHotKeyCode,
        modifiersKey: Key.shortcutsHotKeyModifiers,
        displayNameKey: Key.shortcutsHotKeyDisplayName
      ) ?? (optionalHotKeysInitialized ? nil : HotKeyAction.shortcuts.defaultConfiguration)
    emojiHotKeyConfiguration =
      Self.loadOptionalHotKey(
        from: userDefaults,
        codeKey: Key.emojiHotKeyCode,
        modifiersKey: Key.emojiHotKeyModifiers,
        displayNameKey: Key.emojiHotKeyDisplayName
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
    let keys =
      action == .shortcuts
      ? (Key.shortcutsHotKeyCode, Key.shortcutsHotKeyModifiers, Key.shortcutsHotKeyDisplayName)
      : (Key.emojiHotKeyCode, Key.emojiHotKeyModifiers, Key.emojiHotKeyDisplayName)
    guard let configuration else {
      userDefaults.removeObject(forKey: keys.0)
      userDefaults.removeObject(forKey: keys.1)
      userDefaults.removeObject(forKey: keys.2)
      return
    }
    userDefaults.set(Int(configuration.keyCode), forKey: keys.0)
    userDefaults.set(Int(configuration.modifiers), forKey: keys.1)
    userDefaults.set(configuration.displayName, forKey: keys.2)
  }
}
