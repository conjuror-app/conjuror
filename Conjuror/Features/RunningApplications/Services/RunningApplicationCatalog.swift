import AppKit
import Foundation

enum RunningApplicationCatalog {
  /// The running apps to list: regular GUI apps other than Conjuror and excluded installations.
  /// Names come from the installed catalog when it has the app, so separate installations keep the
  /// distinct names that application search shows.
  static func applications(
    from candidates: [RunningApplicationCandidate],
    ownProcessIdentifier: pid_t,
    installed: [InstalledApplication],
    excludedPaths: Set<String>
  ) -> [RunningApplication] {
    let installedNames = Dictionary(
      installed.map { ($0.persistenceKey, $0.displayName) },
      uniquingKeysWith: { first, _ in first }
    )

    return candidates.compactMap { candidate in
      guard candidate.isRegular,
        !candidate.isTerminated,
        candidate.processIdentifier != ownProcessIdentifier
      else {
        return nil
      }

      let path = candidate.bundleURL?.canonicalFileURL.path

      if let path, excludedPaths.contains(path) { return nil }

      let displayName =
        path.flatMap { installedNames[$0] }
        ?? candidate.localizedName
        ?? candidate.bundleURL?.deletingPathExtension().lastPathComponent
        ?? "Process \(candidate.processIdentifier)"

      return RunningApplication(
        processIdentifier: candidate.processIdentifier,
        displayName: displayName,
        bundleIdentifier: candidate.bundleIdentifier,
        bundleURL: candidate.bundleURL,
        isHidden: candidate.isHidden
      )
    }
  }
}

struct RunningApplicationCandidate: Equatable {
  let processIdentifier: pid_t
  let localizedName: String?
  let bundleIdentifier: String?
  let bundleURL: URL?
  let isRegular: Bool
  let isHidden: Bool
  let isTerminated: Bool
}

extension RunningApplicationCandidate {
  init(_ application: NSRunningApplication) {
    self.init(
      processIdentifier: application.processIdentifier,
      localizedName: application.localizedName,
      bundleIdentifier: application.bundleIdentifier,
      bundleURL: application.bundleURL,
      isRegular: application.activationPolicy == .regular,
      isHidden: application.isHidden,
      isTerminated: application.isTerminated
    )
  }
}
