import AppKit
import Foundation

struct RunningApplication: Identifiable, Equatable {
  let processIdentifier: pid_t
  let displayName: String
  let bundleIdentifier: String?
  let bundleURL: URL?
  let isHidden: Bool

  @MainActor
  var icon: NSImage {
    bundleURL.map(ApplicationIconCache.shared.icon(for:))
      ?? NSWorkspace.shared.icon(for: .applicationBundle)
  }

  var id: pid_t {
    processIdentifier
  }

  var persistenceKey: String? {
    bundleURL?.canonicalFileURL.path
  }

  var isFinder: Bool {
    bundleIdentifier == "com.apple.finder"
  }
}
