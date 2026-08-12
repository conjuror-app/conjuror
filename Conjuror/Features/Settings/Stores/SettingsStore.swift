import Combine
import Foundation

@MainActor
final class SettingsStore: ObservableObject {
  private enum Key {
    static let hotKeyCode = "settings.hotKeyCode"
    static let hotKeyDisplayName = "settings.hotKeyDisplayName"
    static let hotKeyModifiers = "settings.hotKeyModifiers"
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

  @Published private(set) var hotKeyConfiguration: HotKeyConfiguration
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

    let storedMaximum =
      userDefaults.object(forKey: Key.maximumVisibleResults)
      .map { _ in userDefaults.integer(forKey: Key.maximumVisibleResults) }
      ?? Self.defaultMaximumVisibleResults
    maximumVisibleResults = Self.clampedMaximumVisibleResults(storedMaximum)
    preferredEmojiSkinTone =
      userDefaults.string(forKey: Key.preferredEmojiSkinTone)
      .flatMap(EmojiSkinTone.init(rawValue:)) ?? .default
  }

  func setHotKeyConfiguration(_ configuration: HotKeyConfiguration) {
    hotKeyConfiguration = configuration
    userDefaults.set(Int(configuration.keyCode), forKey: Key.hotKeyCode)
    userDefaults.set(Int(configuration.modifiers), forKey: Key.hotKeyModifiers)
    userDefaults.set(configuration.displayName, forKey: Key.hotKeyDisplayName)
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
}
