import Foundation

@MainActor
final class HotKeyStore: ObservableObject {
  typealias RegistrationFactory = (
    HotKeyConfiguration,
    @escaping () -> Void
  ) throws -> any HotKeyRegistration

  @Published private(set) var registrationErrorMessage: String?

  private let settingsStore: SettingsStore
  private let onHotKeyPressed: (HotKeyAction) -> Void
  private let registrationFactory: RegistrationFactory
  private var registrations = [HotKeyAction: any HotKeyRegistration]()

  init(
    settingsStore: SettingsStore,
    onHotKeyPressed: @escaping (HotKeyAction) -> Void,
    registrationFactory: @escaping RegistrationFactory = { configuration, handler in
      try GlobalHotKey(configuration: configuration, handler: handler)
    }
  ) {
    self.settingsStore = settingsStore
    self.onHotKeyPressed = onHotKeyPressed
    self.registrationFactory = registrationFactory
  }

  func register() {
    registrations.removeAll()
    do {
      for action in HotKeyAction.allCases {
        guard let configuration = settingsStore.hotKeyConfiguration(for: action) else { continue }
        registrations[action] = try makeRegistration(configuration: configuration, action: action)
      }
      registrationErrorMessage = nil
    } catch {
      registrations.removeAll()
      registrationErrorMessage = error.localizedDescription
    }
  }

  func updateConfiguration(
    _ configuration: HotKeyConfiguration?,
    for action: HotKeyAction = .launcher
  ) -> String? {
    let existingConfiguration = settingsStore.hotKeyConfiguration(for: action)
    if configuration == existingConfiguration, registrations[action] != nil || configuration == nil
    {
      registrationErrorMessage = nil
      return nil
    }

    if let configuration,
      HotKeyAction.allCases.contains(where: {
        $0 != action && settingsStore.hotKeyConfiguration(for: $0) == configuration
      })
    {
      return "That shortcut is already assigned in Conjuror."
    }

    registrations[action] = nil
    do {
      if let configuration {
        registrations[action] = try makeRegistration(configuration: configuration, action: action)
      }
      registrationErrorMessage = nil
      settingsStore.setHotKeyConfiguration(configuration, for: action)
      return nil
    } catch {
      if let existingConfiguration {
        registrations[action] = try? makeRegistration(
          configuration: existingConfiguration,
          action: action
        )
      }
      return error.localizedDescription
    }
  }

  func setShortcutRecording(_ isRecording: Bool) {
    if isRecording {
      registrations.removeAll()
    } else {
      register()
    }
  }

  func resetSettings() -> String? {
    settingsStore.resetMaximumVisibleResults()
    settingsStore.setPreferredEmojiSkinTone(.default)
    registrations.removeAll()
    for action in HotKeyAction.allCases {
      settingsStore.setHotKeyConfiguration(action.defaultConfiguration, for: action)
    }
    register()
    return registrationErrorMessage
  }

  private func makeRegistration(
    configuration: HotKeyConfiguration,
    action: HotKeyAction
  ) throws -> any HotKeyRegistration {
    try registrationFactory(configuration) { [onHotKeyPressed] in onHotKeyPressed(action) }
  }
}
