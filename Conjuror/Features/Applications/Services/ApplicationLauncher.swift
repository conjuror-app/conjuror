import AppKit

@MainActor
struct ApplicationLauncher {
  func open(_ application: InstalledApplication) async throws {
    if case .systemSettings(let url) = application.launchTarget {
      guard NSWorkspace.shared.open(url) else {
        throw ApplicationLaunchError.settingsURLNotOpened
      }

      return
    }

    let configuration = NSWorkspace.OpenConfiguration()
    configuration.activates = true

    _ = try await NSWorkspace.shared.openApplication(
      at: application.url,
      configuration: configuration
    )
  }
}

private enum ApplicationLaunchError: LocalizedError {
  case settingsURLNotOpened

  var errorDescription: String? {
    "System Settings did not open."
  }
}
