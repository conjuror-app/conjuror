import AppKit

struct ApplicationLauncher: ApplicationLaunching {
  func open(_ application: InstalledApplication) async throws {
    if case .systemSettings(let url) = application.launchTarget {
      guard NSWorkspace.shared.open(url) else {
        throw ApplicationLaunchError.settingsURLNotOpened
      }
      return
    }

    let configuration = NSWorkspace.OpenConfiguration()
    configuration.activates = true

    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
      NSWorkspace.shared.openApplication(
        at: application.url,
        configuration: configuration
      ) { runningApplication, error in
        if let error {
          continuation.resume(throwing: error)
        } else if runningApplication != nil {
          continuation.resume(returning: ())
        } else {
          continuation.resume(throwing: ApplicationLaunchError.noRunningApplication)
        }
      }
    }
  }
}

protocol ApplicationLaunching {
  @MainActor
  func open(_ application: InstalledApplication) async throws
}

private enum ApplicationLaunchError: LocalizedError {
  case noRunningApplication
  case settingsURLNotOpened

  var errorDescription: String? {
    switch self {
    case .noRunningApplication:
      "The application did not start."
    case .settingsURLNotOpened:
      "System Settings did not open."
    }
  }
}
