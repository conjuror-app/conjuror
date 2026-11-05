import AppKit
import Foundation

/// A snapshot of a running GUI app. Actions look the process up again by its identifier, so the
/// snapshot never holds a stale `NSRunningApplication`.
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

  /// Matches `InstalledApplication.persistenceKey`, so exclusions apply to running apps.
  var persistenceKey: String? {
    bundleURL?.canonicalFileURL.path
  }

  /// Finder relaunches itself and has no Quit command, so Quit All leaves it running.
  var isFinder: Bool {
    bundleIdentifier == "com.apple.finder"
  }
}
