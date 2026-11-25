import Foundation

@MainActor
final class HotKeyStore: ObservableObject {
  typealias RegistrationFactory =
    @MainActor (
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
  private var registrationFailures = [HotKeyTarget: String]()
  private var isRecording = false

  init(
    settingsStore: SettingsStore,
    onHotKeyPressed: @escaping (HotKeyTarget) -> Void,
    registrationFactory: @escaping RegistrationFactory = { configuration, handler in
      configuration.isFunctionKey
        ? try FunctionKeyMonitor(handler: handler)
        : try GlobalHotKey(configuration: configuration, handler: handler)
    }
  ) {
    self.settingsStore = settingsStore
    self.onHotKeyPressed = onHotKeyPressed
    self.registrationFactory = registrationFactory
  }

  func register() {
    registrations.removeAll()
    registrationFailures.removeAll()
    registerMissing()
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

  func removeApplicationCustomization(at path: String) {
    registrations[.application(path: path)] = nil
    registrationFailures[.application(path: path)] = nil
    settingsStore.removeApplicationCustomization(at: path)
    publishRegistrationError()
  }

  /// Registers any assigned shortcuts that aren't registered, for example once Accessibility
  /// access needed by the fn shortcut has been granted. Working shortcuts are left alone.
  func retryFailedRegistrations() {
    guard !isRecording else { return }

    registerMissing()
  }

  func setShortcutRecording(_ isRecording: Bool) {
    self.isRecording = isRecording

    if isRecording {
      registrations.removeAll()
    } else {
      register()
    }
  }

  private func registerMissing() {
    for (target, configuration) in assignedConfigurations() where registrations[target] == nil {
      do {
        registrations[target] = try makeRegistration(configuration: configuration, target: target)
        registrationFailures[target] = nil
      } catch {
        registrationFailures[target] = error.localizedDescription
      }
    }

    publishRegistrationError()
  }

  /// Publishes the first failure among the shortcuts currently assigned, so fixing one
  /// shortcut doesn't hide another that is still unregistered.
  private func publishRegistrationError() {
    let message =
      assignedConfigurations().lazy
      .compactMap { target, _ in self.registrationFailures[target] }
      .first

    if registrationErrorMessage != message {
      registrationErrorMessage = message
    }
  }

  private func assignedConfigurations() -> [(HotKeyTarget, HotKeyConfiguration)] {
    savedConfigurations().filter { target, _ in
      guard case .action(let action) = target else { return true }

      return isAvailable(action)
    }
  }

  private func savedConfigurations() -> [(HotKeyTarget, HotKeyConfiguration)] {
    let actions = HotKeyAction.allCases.compactMap {
      action -> (HotKeyTarget, HotKeyConfiguration)? in
      settingsStore.hotKeyConfiguration(for: action).map { (.action(action), $0) }
    }
    let applications = settingsStore.applicationCustomizations
      .sorted { $0.key < $1.key }
      .compactMap { path, customization in
        customization.hotKey.map { (HotKeyTarget.application(path: path), $0) }
      }

    return actions + applications
  }

  private func isAvailable(_ action: HotKeyAction) -> Bool {
    switch action {
    case .clipboard: settingsStore.isClipboardHistoryEnabled
    case .emoji: settingsStore.isEmojiModeEnabled
    case .files: settingsStore.isFilesModuleEnabled
    case .shortcuts: settingsStore.isShortcutsModeEnabled
    case .launcher: true
    }
  }

  private func owner(
    of configuration: HotKeyConfiguration,
    excluding target: HotKeyTarget
  ) -> String? {
    guard
      let (owner, _) = savedConfigurations().first(where: { candidate, assigned in
        candidate != target && assigned.keyCode == configuration.keyCode
          && assigned.modifiers == configuration.modifiers
      })
    else { return nil }

    switch owner {
    case .action(let action):
      let name = Self.ownerName(of: action)

      return isAvailable(action) ? name : "\(name), which is turned off"
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
      registrationFailures[target] = nil
      publishRegistrationError()

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

      registrationFailures[target] = nil
      save()
      publishRegistrationError()

      return nil
    } catch {
      if let existingConfiguration {
        do {
          registrations[target] = try makeRegistration(
            configuration: existingConfiguration,
            target: target
          )
          registrationFailures[target] = nil
        } catch let restoreError {
          registrationFailures[target] = restoreError.localizedDescription
        }

        publishRegistrationError()
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
