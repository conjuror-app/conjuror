import Combine
import Foundation

@MainActor
final class SettingsStore: ObservableObject {
  private struct HotKeyKeys {
    let code: UserDefaultsKey<Int>
    let displayName: UserDefaultsKey<String>
    let modifiers: UserDefaultsKey<Int>
    /// Set once the default has been stored, so a cleared optional hot key stays cleared.
    let initialized: UserDefaultsKey<Bool>?
  }

  private enum Key {
    static let maximumVisibleResults = UserDefaultsKey<Int>("settings.maximumVisibleResults")
    static let preferredEmojiSkinTone = UserDefaultsKey<String>("settings.preferredEmojiSkinTone")
    static let isFilesModuleEnabled = UserDefaultsKey<Bool>("settings.isFilesModuleEnabled")
    static let excludedApplications = UserDefaultsKey<[String: String]>(
      "settings.excludedApplications"
    )
    static let showsSystemSettingsItems = UserDefaultsKey<Bool>("settings.showsSystemSettingsItems")
    static let showsSystemCommands = UserDefaultsKey<Bool>("settings.showsSystemCommands")
    static let launcherBorderStyle = UserDefaultsKey<String>("settings.launcherBorderStyle")
    static let launcherBorderRed = UserDefaultsKey<Double>("settings.launcherBorderRed")
    static let launcherBorderGreen = UserDefaultsKey<Double>("settings.launcherBorderGreen")
    static let launcherBorderBlue = UserDefaultsKey<Double>("settings.launcherBorderBlue")
    static let launcherAppearance = UserDefaultsKey<String>("settings.launcherAppearance")
    static let quicklinks = UserDefaultsKey<Data>("settings.quicklinks")
    /// An empty string turns the web search fallback off.
    static let webSearchQuicklinkID = UserDefaultsKey<String>("settings.webSearchQuicklinkID")
    static let applicationCustomizations = UserDefaultsKey<Data>(
      "settings.applicationCustomizations"
    )

    static func hotKeyKeys(for action: HotKeyAction) -> HotKeyKeys {
      let (prefix, initialized): (String, String?) =
        switch action {
        case .launcher: ("settings.hotKey", nil)
        case .shortcuts: ("settings.shortcutsHotKey", "settings.optionalHotKeysInitialized")
        case .emoji: ("settings.emojiHotKey", "settings.optionalHotKeysInitialized")
        case .files: ("settings.filesHotKey", "settings.filesHotKeyInitialized")
        }

      return HotKeyKeys(
        code: UserDefaultsKey("\(prefix)Code"),
        displayName: UserDefaultsKey("\(prefix)DisplayName"),
        modifiers: UserDefaultsKey("\(prefix)Modifiers"),
        initialized: initialized.map(UserDefaultsKey.init)
      )
    }
  }

  nonisolated static let defaultMaximumVisibleResults = 7
  nonisolated static let maximumVisibleResultsRange = 3...10

  private static func clampResultCount(_ value: Int) -> Int {
    min(
      max(value, maximumVisibleResultsRange.lowerBound),
      maximumVisibleResultsRange.upperBound
    )
  }

  private static func loadHotKey(
    from userDefaults: UserDefaults,
    keys: HotKeyKeys
  ) -> HotKeyConfiguration? {
    guard let storedCode = userDefaults.value(for: keys.code),
      let storedModifiers = userDefaults.value(for: keys.modifiers),
      let code = UInt32(exactly: storedCode),
      let modifiers = UInt32(exactly: storedModifiers),
      let displayName = userDefaults.value(for: keys.displayName)
    else { return nil }

    return HotKeyConfiguration(
      keyCode: code,
      modifiers: modifiers,
      displayName: displayName
    )
  }

  @Published private(set) var maximumVisibleResults: Int
  @Published private(set) var preferredEmojiSkinTone: EmojiSkinTone
  @Published private(set) var isFilesModuleEnabled: Bool
  /// Canonical installation paths mapped to names, including apps no longer installed.
  @Published private(set) var excludedApplications: [String: String]
  @Published private(set) var showsSystemSettingsItems: Bool
  @Published private(set) var showsSystemCommands: Bool
  @Published private(set) var launcherBorderStyle: LauncherBorderStyle
  @Published private(set) var launcherCustomBorderColor: LauncherBorderColor
  @Published private(set) var launcherAppearance: LauncherAppearance
  @Published private(set) var quicklinks: [Quicklink]
  @Published private(set) var webSearchQuicklinkID: Quicklink.ID?
  /// Aliases and hot keys by canonical installation path, including apps no longer installed.
  @Published private(set) var applicationCustomizations: [String: ApplicationCustomization]

  var hotKeyConfiguration: HotKeyConfiguration {
    hotKeyConfigurations[.launcher] ?? .defaultValue
  }

  /// The quicklink the web search fallback row uses, if it still exists and accepts search text.
  var webSearchQuicklink: Quicklink? {
    quicklinks.first { $0.id == webSearchQuicklinkID && $0.acceptsQuery }
  }

  @Published private var hotKeyConfigurations: [HotKeyAction: HotKeyConfiguration]

  private let userDefaults: UserDefaults

  init(userDefaults: UserDefaults = .standard) {
    self.userDefaults = userDefaults

    var hotKeyConfigurations = [HotKeyAction: HotKeyConfiguration]()
    var uninitializedActions = [HotKeyAction]()

    for action in HotKeyAction.allCases {
      let keys = Key.hotKeyKeys(for: action)
      let isInitialized = keys.initialized.flatMap(userDefaults.value(for:)) ?? false

      if keys.initialized != nil, !isInitialized { uninitializedActions.append(action) }

      hotKeyConfigurations[action] =
        Self.loadHotKey(from: userDefaults, keys: keys)
        ?? (isInitialized ? nil : action.defaultConfiguration)
    }

    self.hotKeyConfigurations = hotKeyConfigurations

    let storedMaximum =
      userDefaults.value(for: Key.maximumVisibleResults)
      ?? Self.defaultMaximumVisibleResults
    maximumVisibleResults = Self.clampResultCount(storedMaximum)
    preferredEmojiSkinTone =
      userDefaults.value(for: Key.preferredEmojiSkinTone)
      .flatMap(EmojiSkinTone.init(rawValue:)) ?? .default
    isFilesModuleEnabled = userDefaults.value(for: Key.isFilesModuleEnabled) ?? true
    excludedApplications = userDefaults.value(for: Key.excludedApplications) ?? [:]
    showsSystemSettingsItems = userDefaults.value(for: Key.showsSystemSettingsItems) ?? true
    showsSystemCommands = userDefaults.value(for: Key.showsSystemCommands) ?? true
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
    // Built-ins are used until the first edit, so removed built-ins stay removed afterwards.
    quicklinks =
      userDefaults.value(for: Key.quicklinks)
      .flatMap { try? JSONDecoder().decode([Quicklink].self, from: $0) } ?? Quicklink.builtIns
    webSearchQuicklinkID =
      userDefaults.value(for: Key.webSearchQuicklinkID)
      .map(UUID.init(uuidString:)) ?? Quicklink.defaultWebSearchID
    applicationCustomizations =
      userDefaults.value(for: Key.applicationCustomizations)
      .flatMap { try? JSONDecoder().decode([String: ApplicationCustomization].self, from: $0) }
      ?? [:]

    for action in uninitializedActions {
      persistHotKey(hotKeyConfigurations[action], for: action)

      if let initialized = Key.hotKeyKeys(for: action).initialized {
        userDefaults.set(true, for: initialized)
      }
    }
  }

  func hotKeyConfiguration(for action: HotKeyAction) -> HotKeyConfiguration? {
    hotKeyConfigurations[action]
  }

  func setHotKeyConfiguration(
    _ configuration: HotKeyConfiguration?,
    for action: HotKeyAction = .launcher
  ) {
    // The launcher hot key cannot be cleared.
    guard configuration != nil || action != .launcher else { return }

    hotKeyConfigurations[action] = configuration
    persistHotKey(configuration, for: action)
  }

  func setMaximumVisibleResults(_ value: Int) {
    let clampedValue = Self.clampResultCount(value)
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

  func excludeApplication(_ application: InstalledApplication) {
    guard !application.isSystemSettingsItem else { return }

    var exclusions = excludedApplications
    exclusions[application.persistenceKey] = application.displayName
    setExcludedApplications(exclusions)
  }

  func removeExcludedApplication(at path: String) {
    var exclusions = excludedApplications
    exclusions.removeValue(forKey: path)
    setExcludedApplications(exclusions)
  }

  /// Saves the app's alias, returning why it can't be used instead when it's invalid. An empty
  /// alias removes it.
  func setAlias(_ alias: String, for application: InstalledApplication) -> String? {
    let alias = alias.trimmingCharacters(in: .whitespacesAndNewlines)

    if !alias.isEmpty,
      let error = ApplicationCustomization.validationError(
        forAlias: alias,
        path: application.persistenceKey,
        among: applicationCustomizations
      )
    {
      return error
    }

    updateCustomization(for: application) { $0.alias = alias.isEmpty ? nil : alias }

    return nil
  }

  /// Stores the app's hot key. `HotKeyStore` registers it first.
  func setApplicationHotKey(
    _ configuration: HotKeyConfiguration?,
    for application: InstalledApplication
  ) {
    updateCustomization(for: application) { $0.hotKey = configuration }
  }

  func removeApplicationCustomization(at path: String) {
    var customizations = applicationCustomizations
    customizations.removeValue(forKey: path)
    setApplicationCustomizations(customizations)
  }

  /// Moves each customization of a deleted app to the one installed app with the same bundle
  /// identifier, and returns whether any moved. Paths on other volumes stay, since an unmounted
  /// volume's apps aren't deleted.
  @discardableResult
  func relocateApplicationCustomizations(
    installed applications: [InstalledApplication],
    fileExists: (String) -> Bool = { FileManager.default.fileExists(atPath: $0) }
  ) -> Bool {
    let installedPaths = Set(applications.map(\.persistenceKey))
    let applicationsByBundleIdentifier = Dictionary(
      grouping: applications.filter { !$0.isSystemSettingsItem && $0.bundleIdentifier != nil },
      by: { $0.bundleIdentifier!.lowercased() }
    )
    var customizations = applicationCustomizations
    var didMove = false

    for (path, customization) in applicationCustomizations.sorted(by: { $0.key < $1.key })
    where !installedPaths.contains(path) {
      guard !path.hasPrefix("/Volumes/"), !fileExists(path),
        let bundleIdentifier = customization.bundleIdentifier?.lowercased(),
        let matches = applicationsByBundleIdentifier[bundleIdentifier], matches.count == 1,
        customizations[matches[0].persistenceKey] == nil
      else { continue }

      var moved = customization
      moved.name = matches[0].displayName
      customizations[path] = nil
      customizations[matches[0].persistenceKey] = moved
      didMove = true
    }

    if didMove { setApplicationCustomizations(customizations) }

    return didMove
  }

  func setShowsSystemSettingsItems(_ showsItems: Bool) {
    showsSystemSettingsItems = showsItems
    userDefaults.set(showsItems, for: Key.showsSystemSettingsItems)
  }

  func setShowsSystemCommands(_ showsCommands: Bool) {
    showsSystemCommands = showsCommands
    userDefaults.set(showsCommands, for: Key.showsSystemCommands)
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

  /// Adds or replaces the quicklink, returning why it can't be saved instead when it's invalid.
  func saveQuicklink(_ quicklink: Quicklink) -> String? {
    if let error = Quicklink.validationError(for: quicklink, among: quicklinks) { return error }

    var quicklinks = quicklinks
    if let index = quicklinks.firstIndex(where: { $0.id == quicklink.id }) {
      quicklinks[index] = quicklink
    } else {
      quicklinks.append(quicklink)
    }
    setQuicklinks(quicklinks)

    return nil
  }

  func removeQuicklink(id: Quicklink.ID) {
    setQuicklinks(quicklinks.filter { $0.id != id })
  }

  func setWebSearchQuicklink(id: Quicklink.ID?) {
    webSearchQuicklinkID = id
    userDefaults.set(id?.uuidString ?? "", for: Key.webSearchQuicklinkID)
  }

  /// Adds back removed built-ins without changing edited ones. A restored built-in whose keyword
  /// another quicklink now uses comes back without a keyword.
  func restoreBuiltInQuicklinks() {
    var quicklinks = quicklinks

    for builtIn in Quicklink.builtIns where !quicklinks.contains(where: { $0.id == builtIn.id }) {
      let keywordIsTaken = quicklinks.contains {
        $0.keyword?.lowercased() == builtIn.keyword?.lowercased()
      }
      quicklinks.append(
        keywordIsTaken
          ? Quicklink(
            id: builtIn.id,
            name: builtIn.name,
            urlTemplate: builtIn.urlTemplate,
            target: builtIn.target
          )
          : builtIn
      )
    }

    setQuicklinks(quicklinks)
  }

  func resetMaximumVisibleResults() {
    setMaximumVisibleResults(Self.defaultMaximumVisibleResults)
  }

  func resetToDefaults() {
    resetMaximumVisibleResults()
    setExcludedApplications([:])
    setApplicationCustomizations([:])
    setPreferredEmojiSkinTone(.default)
    setLauncherBorderStyle(.cyan)
    setLauncherCustomBorderColor(.default)

    for action in HotKeyAction.allCases {
      setHotKeyConfiguration(action.defaultConfiguration, for: action)
    }
  }

  private func setExcludedApplications(_ exclusions: [String: String]) {
    excludedApplications = exclusions
    userDefaults.set(exclusions, for: Key.excludedApplications)
  }

  private func setQuicklinks(_ quicklinks: [Quicklink]) {
    self.quicklinks = quicklinks
    if let data = try? JSONEncoder().encode(quicklinks) {
      userDefaults.set(data, for: Key.quicklinks)
    }

    if webSearchQuicklinkID != nil, webSearchQuicklink == nil { setWebSearchQuicklink(id: nil) }
  }

  private func setApplicationCustomizations(
    _ customizations: [String: ApplicationCustomization]
  ) {
    let customizations = customizations.filter { !$0.value.isEmpty }
    applicationCustomizations = customizations

    if let data = try? JSONEncoder().encode(customizations) {
      userDefaults.set(data, for: Key.applicationCustomizations)
    }
  }

  private func updateCustomization(
    for application: InstalledApplication,
    _ change: (inout ApplicationCustomization) -> Void
  ) {
    let path = application.persistenceKey
    var customization =
      applicationCustomizations[path]
      ?? ApplicationCustomization(
        name: application.displayName,
        bundleIdentifier: application.bundleIdentifier
      )
    customization.name = application.displayName
    change(&customization)

    var customizations = applicationCustomizations
    customizations[path] = customization
    setApplicationCustomizations(customizations)
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
