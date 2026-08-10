import Foundation

@MainActor
final class HotKeyStore: ObservableObject {
  typealias RegistrationFactory = (
    HotKeyConfiguration,
    @escaping () -> Void
  ) throws -> any HotKeyRegistration

  @Published private(set) var registrationErrorMessage: String?

  private let settingsStore: SettingsStore
  private let onHotKeyPressed: () -> Void
  private let registrationFactory: RegistrationFactory
  private var registration: (any HotKeyRegistration)?

  init(
    settingsStore: SettingsStore,
    onHotKeyPressed: @escaping () -> Void,
    registrationFactory: @escaping RegistrationFactory = { configuration, handler in
      try GlobalHotKey(configuration: configuration, handler: handler)
    }
  ) {
    self.settingsStore = settingsStore
    self.onHotKeyPressed = onHotKeyPressed
    self.registrationFactory = registrationFactory
  }

  func register() {
    do {
      registration = try makeRegistration(
        configuration: settingsStore.hotKeyConfiguration
      )
      registrationErrorMessage = nil
    } catch {
      registration = nil
      registrationErrorMessage = error.localizedDescription
    }
  }

  func updateConfiguration(_ configuration: HotKeyConfiguration) -> String? {
    if configuration == settingsStore.hotKeyConfiguration {
      guard registration == nil else {
        registrationErrorMessage = nil
        return nil
      }

      register()
      return registrationErrorMessage
    }

    do {
      let replacement = try makeRegistration(configuration: configuration)
      registration = replacement
      registrationErrorMessage = nil
      settingsStore.setHotKeyConfiguration(configuration)
      return nil
    } catch {
      return error.localizedDescription
    }
  }

  func setShortcutRecording(_ isRecording: Bool) {
    if isRecording {
      registration = nil
    } else if registration == nil {
      register()
    }
  }

  func resetSettings() -> String? {
    settingsStore.resetMaximumVisibleResults()
    return updateConfiguration(.defaultValue)
  }

  private func makeRegistration(
    configuration: HotKeyConfiguration
  ) throws -> any HotKeyRegistration {
    try registrationFactory(configuration, onHotKeyPressed)
  }
}
