import AppKit

@MainActor
struct FileOpener {
  func open(_ url: URL) throws {
    guard NSWorkspace.shared.open(url) else {
      throw FileOpenError.failed
    }
  }
}

private enum FileOpenError: LocalizedError {
  case failed

  var errorDescription: String? {
    "The item could not be opened."
  }
}
