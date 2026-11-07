import Foundation

@MainActor
final class HotKeyStore: ObservableObject {
  typealias RegistrationFactory = (
    HotKeyConfiguration,
    @escaping () -> Void
  ) throws -> AnyObject

  private static func ownerName(of action: HotKeyAction) -> String {
    switch action {
    case .launcher: "the launcher"
    case .shortcuts: "Shortcuts mode"
    case .emoji: "Emoji mode"
    case .files: "Files mode"
    case .clipboard: "Clipboard history"
    }
  }

  @Published private(set) var registrationErrorMessage: String?

  private let settingsStore: SettingsStore
  private let onHotKeyPressed: (HotKeyTarget) -> Void
  private let registrationFactory: RegistrationFactory
  private var registrations = [HotKeyTarget: AnyObject]()

  init(
    settingsStore: SettingsStore,
    onHotKeyPressed: @escaping (HotKeyTarget) -> Void,
    registrationFactory: @escaping RegistrationFactory = { configuration, handler in
      try GlobalHotKey(configuration: configuration, handler: handler)
    }
  ) {
    self.settingsStore = settingsStore
    self.onHotKeyPressed = onHotKeyPressed
    self.registrationFactory = registrationFactory
  }

  /// Registers every assigned hot key. Each registers on its own, so one that's unavailable
  /// doesn't stop the others, and the first failure is published.
  func register() {
    registrations.removeAll()
    var firstError: Error?

    for (target, configuration) in assignedConfigurations() {
      do {
        registrations[target] = try makeRegistration(configuration: configuration, target: target)
      } catch {
        firstError = firstError ?? error
      }
    }

    registrationErrorMessage = firstError?.localizedDescription
  }

  func updateConfiguration(
    _ configuration: HotKeyConfiguration?,
    for action: HotKeyAction = .launcher
  ) -> String? {
    update(
      configuration,
      for: .action(action),
      existingConfiguration: settingsStore.hotKeyConfiguration(for: action)
    ) {
      settingsStore.setHotKeyConfiguration(configuration, for: action)
    }
  }

  func updateHotKey(
    _ configuration: HotKeyConfiguration?,
    for application: InstalledApplication
  ) -> String? {
    let path = application.persistenceKey

    return update(
      configuration,
      for: .application(path: path),
      existingConfiguration: settingsStore.applicationCustomizations[path]?.hotKey
    ) {
      settingsStore.setApplicationHotKey(configuration, for: application)
    }
  }

  /// Unregisters the app's hot key and removes its alias and hot key.
  func removeApplicationCustomization(at path: String) {
    registrations[.application(path: path)] = nil
    settingsStore.removeApplicationCustomization(at: path)
  }

  func setShortcutRecording(_ isRecording: Bool) {
    if isRecording {
      registrations.removeAll()
    } else {
      register()
    }
  }

  /// Launcher actions first, then apps by path, so registration order is stable. Clipboard
  /// history's hot key stays free for other apps until history is turned on.
  private func assignedConfigurations() -> [(HotKeyTarget, HotKeyConfiguration)] {
    let actions = HotKeyAction.allCases.compactMap {
      action -> (HotKeyTarget, HotKeyConfiguration)? in
      guard action != .clipboard || settingsStore.isClipboardHistoryEnabled else { return nil }

      return settingsStore.hotKeyConfiguration(for: action).map { (.action(action), $0) }
    }
    let applications = settingsStore.applicationCustomizations
      .sorted { $0.key < $1.key }
      .compactMap { path, customization in
        customization.hotKey.map { (HotKeyTarget.application(path: path), $0) }
      }

    return actions + applications
  }

  /// What already uses the configuration's keys, other than `target`.
  private func owner(
    of configuration: HotKeyConfiguration,
    excluding target: HotKeyTarget
  ) -> String? {
    guard
      let (owner, _) = assignedConfigurations().first(where: { candidate, assigned in
        candidate != target && assigned.keyCode == configuration.keyCode
          && assigned.modifiers == configuration.modifiers
      })
    else { return nil }

    switch owner {
    case .action(let action):
      return Self.ownerName(of: action)
    case .application(let path):
      return settingsStore.applicationCustomizations[path]?.name ?? path
    }
  }

  private func update(
    _ configuration: HotKeyConfiguration?,
    for target: HotKeyTarget,
    existingConfiguration: HotKeyConfiguration?,
    save: () -> Void
  ) -> String? {
    if configuration == existingConfiguration, registrations[target] != nil || configuration == nil
    {
      registrationErrorMessage = nil

      return nil
    }

    if let configuration, let owner = owner(of: configuration, excluding: target) {
      return "That shortcut is already used by \(owner)."
    }

    registrations[target] = nil

    do {
      if let configuration {
        registrations[target] = try makeRegistration(configuration: configuration, target: target)
      }

      registrationErrorMessage = nil
      save()

      return nil
    } catch {
      if let existingConfiguration {
        registrations[target] = try? makeRegistration(
          configuration: existingConfiguration,
          target: target
        )
      }

      return error.localizedDescription
    }
  }

  private func makeRegistration(
    configuration: HotKeyConfiguration,
    target: HotKeyTarget
  ) throws -> AnyObject {
    try registrationFactory(configuration) { [onHotKeyPressed] in onHotKeyPressed(target) }
  }
}
