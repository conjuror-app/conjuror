import AppKit

/// Opens an app from its hot key, or hides it when it's already frontmost.
@MainActor
struct ApplicationActivator {
  let launcher = ApplicationLauncher()

  func toggle(path: String) async throws {
    if let frontmost = NSWorkspace.shared.frontmostApplication,
      frontmost.bundleURL?.canonicalFileURL.path == path
    {
      frontmost.hide()

      return
    }

    guard FileManager.default.fileExists(atPath: path) else {
      throw CocoaError(.fileNoSuchFile, userInfo: [NSFilePathErrorKey: path])
    }

    try await launcher.open(
      InstalledApplication(
        displayName: URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent,
        bundleIdentifier: nil,
        url: URL(fileURLWithPath: path)
      )
    )
  }
}
