import AppKit

@MainActor
struct QuicklinkOpener {
  func open(_ url: URL, target: Quicklink.Target) async throws {
    switch target {
    case .defaultApplication:
      guard NSWorkspace.shared.open(url) else { throw QuicklinkOpenError.notOpened }
    case .application(let path):
      guard FileManager.default.fileExists(atPath: path) else {
        throw QuicklinkOpenError.applicationMissing(
          FileManager.default.displayName(atPath: path)
        )
      }

      let configuration = NSWorkspace.OpenConfiguration()
      configuration.activates = true
      _ = try await NSWorkspace.shared.open(
        [url],
        withApplicationAt: URL(fileURLWithPath: path),
        configuration: configuration
      )
    }
  }
}

private enum QuicklinkOpenError: LocalizedError {
  case applicationMissing(String)
  case notOpened

  var errorDescription: String? {
    switch self {
    case .applicationMissing(let name):
      "\(name) is no longer installed at its saved location."
    case .notOpened:
      "No app opened the link."
    }
  }
}
