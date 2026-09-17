import Combine
import Foundation

@MainActor
final class SettingsStore: ObservableObject {
  private struct HotKeyKeys {
    let code: UserDefaultsKey<Int>
    let displayName: UserDefaultsKey<String>
    let modifiers: UserDefaultsKey<Int>
  }

  private enum Key {
    static let filesHotKeyInitialized = UserDefaultsKey<Bool>("settings.filesHotKeyInitialized")
    static let optionalHotKeysInitialized = UserDefaultsKey<Bool>(
      "settings.optionalHotKeysInitialized"
    )
    static let maximumVisibleResults = UserDefaultsKey<Int>("settings.maximumVisibleResults")
    static let preferredEmojiSkinTone = UserDefaultsKey<String>("settings.preferredEmojiSkinTone")
    static let isFilesModuleEnabled = UserDefaultsKey<Bool>("settings.isFilesModuleEnabled")
    static let showsSystemSettingsItems = UserDefaultsKey<Bool>("settings.showsSystemSettingsItems")
    static let launcherBorderStyle = UserDefaultsKey<String>("settings.launcherBorderStyle")
    static let launcherBorderRed = UserDefaultsKey<Double>("settings.launcherBorderRed")
    static let launcherBorderGreen = UserDefaultsKey<Double>("settings.launcherBorderGreen")
    static let launcherBorderBlue = UserDefaultsKey<Double>("settings.launcherBorderBlue")
    static let launcherAppearance = UserDefaultsKey<String>("settings.launcherAppearance")

    static func hotKeyKeys(for action: HotKeyAction) -> HotKeyKeys {
      let prefix =
        switch action {
        case .launcher: "settings.hotKey"
        case .shortcuts: "settings.shortcutsHotKey"
        case .emoji: "settings.emojiHotKey"
        case .files: "settings.filesHotKey"
        }
      return HotKeyKeys(
        code: UserDefaultsKey("\(prefix)Code"),
        displayName: UserDefaultsKey("\(prefix)DisplayName"),
        modifiers: UserDefaultsKey("\(prefix)Modifiers")
      )
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

  private static func loadHotKey(
    from userDefaults: UserDefaults,
    keys: HotKeyKeys
  ) -> HotKeyConfiguration? {
    guard userDefaults.value(for: keys.code) != nil,
      userDefaults.value(for: keys.modifiers) != nil,
      let displayName = userDefaults.value(for: keys.displayName)
    else { return nil }
    return HotKeyConfiguration(
      keyCode: UInt32((userDefaults.value(for: keys.code) ?? 0)),
      modifiers: UInt32((userDefaults.value(for: keys.modifiers) ?? 0)),
      displayName: displayName
    )
  }

  @Published private(set) var hotKeyConfiguration: HotKeyConfiguration
  @Published private(set) var shortcutsHotKeyConfiguration: HotKeyConfiguration?
  @Published private(set) var emojiHotKeyConfiguration: HotKeyConfiguration?
  @Published private(set) var filesHotKeyConfiguration: HotKeyConfiguration?
  @Published private(set) var maximumVisibleResults: Int
  @Published private(set) var preferredEmojiSkinTone: EmojiSkinTone
  @Published private(set) var isFilesModuleEnabled: Bool
  @Published private(set) var showsSystemSettingsItems: Bool
  @Published private(set) var launcherBorderStyle: LauncherBorderStyle
  @Published private(set) var launcherCustomBorderColor: LauncherBorderColor
  @Published private(set) var launcherAppearance: LauncherAppearance

  private let userDefaults: UserDefaults

  init(userDefaults: UserDefaults = .standard) {
    self.userDefaults = userDefaults

    hotKeyConfiguration =
      Self.loadHotKey(
        from: userDefaults,
        keys: Key.hotKeyKeys(for: .launcher)
      ) ?? .defaultValue

    let optionalHotKeysInitialized =
      (userDefaults.value(for: Key.optionalHotKeysInitialized) ?? false)
    shortcutsHotKeyConfiguration =
      Self.loadHotKey(
        from: userDefaults,
        keys: Key.hotKeyKeys(for: .shortcuts)
      ) ?? (optionalHotKeysInitialized ? nil : HotKeyAction.shortcuts.defaultConfiguration)
    emojiHotKeyConfiguration =
      Self.loadHotKey(
        from: userDefaults,
        keys: Key.hotKeyKeys(for: .emoji)
      ) ?? (optionalHotKeysInitialized ? nil : HotKeyAction.emoji.defaultConfiguration)
    let filesHotKeyInitialized = userDefaults.value(for: Key.filesHotKeyInitialized) ?? false
    filesHotKeyConfiguration =
      Self.loadHotKey(
        from: userDefaults,
        keys: Key.hotKeyKeys(for: .files)
      ) ?? (filesHotKeyInitialized ? nil : HotKeyAction.files.defaultConfiguration)
    let storedMaximum =
      userDefaults.value(for: Key.maximumVisibleResults)
      ?? Self.defaultMaximumVisibleResults
    maximumVisibleResults = Self.clampedMaximumVisibleResults(storedMaximum)
    preferredEmojiSkinTone =
      userDefaults.value(for: Key.preferredEmojiSkinTone)
      .flatMap(EmojiSkinTone.init(rawValue:)) ?? .default
    isFilesModuleEnabled = userDefaults.value(for: Key.isFilesModuleEnabled) ?? true
    showsSystemSettingsItems = userDefaults.value(for: Key.showsSystemSettingsItems) ?? true
    launcherBorderStyle =
      userDefaults.value(for: Key.launcherBorderStyle)
      .flatMap(LauncherBorderStyle.init(rawValue:)) ?? .cyan
    launcherCustomBorderColor = LauncherBorderColor(
      red: userDefaults.value(for: Key.launcherBorderRed) ?? LauncherBorderColor.default.red,
      green: userDefaults.value(for: Key.launcherBorderGreen) ?? LauncherBorderColor.default.green,
      blue: userDefaults.value(for: Key.launcherBorderBlue) ?? LauncherBorderColor.default.blue
    )
    launcherAppearance =
      userDefaults.value(for: Key.launcherAppearance)
      .flatMap(LauncherAppearance.init(rawValue:)) ?? .standard

    if !optionalHotKeysInitialized {
      userDefaults.set(true, for: Key.optionalHotKeysInitialized)
      persistHotKey(shortcutsHotKeyConfiguration, for: .shortcuts)
      persistHotKey(emojiHotKeyConfiguration, for: .emoji)
    }
    if !filesHotKeyInitialized {
      userDefaults.set(true, for: Key.filesHotKeyInitialized)
      persistHotKey(filesHotKeyConfiguration, for: .files)
    }
  }

  func hotKeyConfiguration(for action: HotKeyAction) -> HotKeyConfiguration? {
    switch action {
    case .launcher: hotKeyConfiguration
    case .shortcuts: shortcutsHotKeyConfiguration
    case .emoji: emojiHotKeyConfiguration
    case .files: filesHotKeyConfiguration
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
    case .shortcuts:
      shortcutsHotKeyConfiguration = configuration
    case .emoji:
      emojiHotKeyConfiguration = configuration
    case .files:
      filesHotKeyConfiguration = configuration
    }
    persistHotKey(configuration, for: action)
  }

  func setMaximumVisibleResults(_ value: Int) {
    let clampedValue = Self.clampedMaximumVisibleResults(value)
    maximumVisibleResults = clampedValue
    userDefaults.set(clampedValue, for: Key.maximumVisibleResults)
  }

  func setPreferredEmojiSkinTone(_ skinTone: EmojiSkinTone) {
    preferredEmojiSkinTone = skinTone
    userDefaults.set(skinTone.rawValue, for: Key.preferredEmojiSkinTone)
  }

  func setFilesModuleEnabled(_ isEnabled: Bool) {
    isFilesModuleEnabled = isEnabled
    userDefaults.set(isEnabled, for: Key.isFilesModuleEnabled)
  }

  func setShowsSystemSettingsItems(_ showsItems: Bool) {
    showsSystemSettingsItems = showsItems
    userDefaults.set(showsItems, for: Key.showsSystemSettingsItems)
  }

  func setLauncherBorderStyle(_ style: LauncherBorderStyle) {
    launcherBorderStyle = style
    userDefaults.set(style.rawValue, for: Key.launcherBorderStyle)
  }

  func setLauncherAppearance(_ appearance: LauncherAppearance) {
    launcherAppearance = appearance
    userDefaults.set(appearance.rawValue, for: Key.launcherAppearance)
  }

  func setLauncherCustomBorderColor(_ color: LauncherBorderColor) {
    launcherCustomBorderColor = color
    userDefaults.set(color.red, for: Key.launcherBorderRed)
    userDefaults.set(color.green, for: Key.launcherBorderGreen)
    userDefaults.set(color.blue, for: Key.launcherBorderBlue)
  }

  func resetMaximumVisibleResults() {
    setMaximumVisibleResults(Self.defaultMaximumVisibleResults)
  }

  private func persistHotKey(
    _ configuration: HotKeyConfiguration?,
    for action: HotKeyAction
  ) {
    let keys = Key.hotKeyKeys(for: action)
    guard let configuration else {
      userDefaults.removeObject(forKey: keys.code.name)
      userDefaults.removeObject(forKey: keys.modifiers.name)
      userDefaults.removeObject(forKey: keys.displayName.name)
      return
    }
    userDefaults.set(Int(configuration.keyCode), for: keys.code)
    userDefaults.set(Int(configuration.modifiers), for: keys.modifiers)
    userDefaults.set(configuration.displayName, for: keys.displayName)
  }
}

enum LauncherAppearance: String, CaseIterable, Identifiable {
  case standard
  case minimal

  var id: Self { self }

  var displayName: String {
    switch self {
    case .standard: "Standard"
    case .minimal: "Minimal"
    }
  }
}

enum LauncherBorderStyle: String, CaseIterable, Identifiable {
  case disabled
  case cyan
  case purple
  case yellow
  case custom

  var id: Self { self }

  var displayName: String {
    switch self {
    case .disabled: "Disabled"
    case .cyan: "Cyan"
    case .purple: "Purple"
    case .yellow: "Yellow"
    case .custom: "Custom"
    }
  }
}

struct LauncherBorderColor: Equatable {
  static let `default` = LauncherBorderColor(
    red: 66 / 255,
    green: 216 / 255,
    blue: 239 / 255
  )

  let red: Double
  let green: Double
  let blue: Double
}
