import AppKit
import Combine
import ServiceManagement

@MainActor
final class LaunchAtLoginStore: ObservableObject {
  @Published private(set) var status: LaunchAtLoginStatus
  @Published private(set) var errorMessage: String?

  var isEnabled: Bool {
    status == .enabled || status == .requiresApproval
  }

  private let service: any LaunchAtLoginServicing
  private let openLoginItemsSettingsAction: () -> Void

  init(
    service: any LaunchAtLoginServicing = LaunchAtLoginService(),
    openLoginItemsSettings: @escaping () -> Void = {
      guard
        let url = URL(
          string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension"
        )
      else { return }
      NSWorkspace.shared.open(url)
    }
  ) {
    self.service = service
    self.openLoginItemsSettingsAction = openLoginItemsSettings
    status = service.status
  }

  func setEnabled(_ isEnabled: Bool) {
    errorMessage = nil

    do {
      if isEnabled {
        try service.register()
      } else {
        try service.unregister()
      }

      status = service.status
    } catch {
      status = service.status
      errorMessage = "Couldn’t update launch at login. \(error.localizedDescription)"
    }
  }

  func refresh() {
    status = service.status
  }

  func openLoginItemsSettings() {
    openLoginItemsSettingsAction()
  }
}

protocol LaunchAtLoginServicing {
  var status: LaunchAtLoginStatus { get }

  func register() throws
  func unregister() throws
}

enum LaunchAtLoginStatus {
  case enabled
  case notRegistered
  case requiresApproval
  case unavailable
}

struct LaunchAtLoginService: LaunchAtLoginServicing {
  var status: LaunchAtLoginStatus {
    switch SMAppService.mainApp.status {
    case .enabled:
      .enabled
    case .notRegistered:
      .notRegistered
    case .requiresApproval:
      .requiresApproval
    case .notFound:
      .unavailable
    @unknown default:
      .unavailable
    }
  }

  func register() throws {
    try SMAppService.mainApp.register()
  }

  func unregister() throws {
    try SMAppService.mainApp.unregister()
  }
}
