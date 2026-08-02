import AppKit

protocol ApplicationLaunching {
    func open(_ application: InstalledApplication) async throws
}

struct ApplicationLauncher: ApplicationLaunching {
    func open(_ application: InstalledApplication) async throws {
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

private enum ApplicationLaunchError: LocalizedError {
    case noRunningApplication

    var errorDescription: String? {
        "The application did not start."
    }
}
