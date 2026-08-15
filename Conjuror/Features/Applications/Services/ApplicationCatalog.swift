import Foundation

struct ApplicationCatalog: ApplicationCatalogLoading {
  static func applicationDirectories(
    fileManager: FileManager = .default,
    mountedVolumeURLs: [URL]? = nil
  ) -> [URL] {
    let standardDirectories = [
      URL(fileURLWithPath: "/Applications", isDirectory: true),
      URL(fileURLWithPath: "/System/Applications", isDirectory: true),
      URL(fileURLWithPath: "/System/Applications/Utilities", isDirectory: true),
      fileManager.homeDirectoryForCurrentUser
        .appendingPathComponent("Applications", isDirectory: true),
    ]
    let mountedVolumes =
      mountedVolumeURLs
      ?? fileManager.mountedVolumeURLs(
        includingResourceValuesForKeys: nil,
        options: [.skipHiddenVolumes]
      )
      ?? []
    let mountedApplicationDirectories =
      mountedVolumes
      .map { $0.appendingPathComponent("Applications", isDirectory: true) }
      .filter { fileManager.fileExists(atPath: $0.path) }

    var seenPaths = Set<String>()
    return (standardDirectories + mountedApplicationDirectories).filter { directory in
      seenPaths.insert(canonicalURL(directory).path).inserted
    }
  }

  static func filteredAndDeduplicated(
    _ candidates: [ApplicationCatalogCandidate],
    excludingBundleIdentifier: String?
  ) -> [ApplicationCatalogCandidate] {
    let excludedIdentifier = excludingBundleIdentifier?.lowercased()
    var seenBundleIdentifiers = Set<String>()
    var seenURLs = Set<String>()

    return
      candidates
      .sorted(by: candidateOrder)
      .filter { candidate in
        guard !candidate.isBackgroundOnly, !candidate.isHelper else {
          return false
        }

        let canonicalPath = canonicalURL(candidate.url).path
        guard seenURLs.insert(canonicalPath).inserted else {
          return false
        }

        if let bundleIdentifier = candidate.bundleIdentifier?.lowercased() {
          guard bundleIdentifier != excludedIdentifier else {
            return false
          }
          guard seenBundleIdentifiers.insert(bundleIdentifier).inserted else {
            return false
          }
        } else if candidate.displayName.caseInsensitiveCompare("Conjuror") == .orderedSame {
          return false
        }

        return true
      }
  }

  static func scan(directories: [URL]) throws -> [ApplicationCatalogCandidate] {
    let fileManager = FileManager.default
    var candidates = [ApplicationCatalogCandidate]()
    var readableDirectoryCount = 0
    var unreadableDirectories = [URL]()

    for (sourcePriority, directory) in directories.enumerated() {
      try Task.checkCancellation()
      guard fileManager.fileExists(atPath: directory.path) else {
        continue
      }

      let keys: [URLResourceKey] = [.isDirectoryKey, .isPackageKey]
      var enumerationError: Error?
      guard
        let enumerator = fileManager.enumerator(
          at: directory,
          includingPropertiesForKeys: keys,
          options: [.skipsHiddenFiles, .skipsPackageDescendants],
          errorHandler: { _, error in
            enumerationError = error
            return false
          }
        )
      else {
        unreadableDirectories.append(directory)
        continue
      }

      for case let url as URL in enumerator
      where url.pathExtension.caseInsensitiveCompare("app") == .orderedSame {
        try Task.checkCancellation()
        guard let candidate = candidate(at: url, sourcePriority: sourcePriority) else {
          continue
        }
        candidates.append(candidate)
      }

      if enumerationError != nil {
        unreadableDirectories.append(directory)
      } else {
        readableDirectoryCount += 1
      }
    }

    if candidates.isEmpty,
      readableDirectoryCount == 0,
      !unreadableDirectories.isEmpty
    {
      throw ApplicationCatalogError.unreadableDirectories(unreadableDirectories)
    }

    return candidates
  }

  private static func candidate(at url: URL, sourcePriority: Int) -> ApplicationCatalogCandidate? {
    guard let bundle = Bundle(url: url),
      let info = bundle.infoDictionary,
      (info["CFBundlePackageType"] as? String) == "APPL"
    else {
      return nil
    }

    let displayName =
      (info["CFBundleDisplayName"] as? String)
      ?? (info["CFBundleName"] as? String)
      ?? url.deletingPathExtension().lastPathComponent
    let pathComponents = Set(url.pathComponents.map { $0.lowercased() })
    let helperDirectories: Set<String> = ["helpers", "xpcservices", "loginitems"]
    let isHelper =
      !pathComponents.isDisjoint(with: helperDirectories)
      || (bundle.bundleIdentifier?.lowercased().contains(".helper") == true)

    return ApplicationCatalogCandidate(
      displayName: displayName,
      bundleIdentifier: bundle.bundleIdentifier,
      url: canonicalURL(url),
      sourcePriority: sourcePriority,
      // Agent applications (LSUIElement) can still be user-facing launch targets, such as
      // Raycast. Only exclude applications that explicitly run in the background.
      isBackgroundOnly: info["LSBackgroundOnly"] as? Bool == true,
      isHelper: isHelper
    )
  }

  private static func candidateOrder(
    _ lhs: ApplicationCatalogCandidate,
    _ rhs: ApplicationCatalogCandidate
  ) -> Bool {
    if lhs.sourcePriority != rhs.sourcePriority {
      return lhs.sourcePriority < rhs.sourcePriority
    }

    let lhsName = ApplicationRanker.normalized(lhs.displayName)
    let rhsName = ApplicationRanker.normalized(rhs.displayName)
    if lhsName != rhsName {
      return lhsName < rhsName
    }

    return canonicalURL(lhs.url).path < canonicalURL(rhs.url).path
  }

  private static func canonicalURL(_ url: URL) -> URL {
    url.standardizedFileURL.resolvingSymlinksInPath()
  }

  private let directoryProvider: () -> [URL]
  private let excludedBundleIdentifier: String?
  private let materializer: ApplicationMaterializing

  init(
    directoryProvider: @escaping () -> [URL] = { Self.applicationDirectories() },
    excludedBundleIdentifier: String? = Bundle.main.bundleIdentifier,
    materializer: ApplicationMaterializing = ApplicationMaterializer()
  ) {
    self.directoryProvider = directoryProvider
    self.excludedBundleIdentifier = excludedBundleIdentifier
    self.materializer = materializer
  }

  func load() async throws -> [InstalledApplication] {
    let directories = directoryProvider()
    let excludedBundleIdentifier = excludedBundleIdentifier

    let scanTask = Task.detached(priority: .userInitiated) {
      let candidates = try Self.scan(directories: directories)
      return Self.filteredAndDeduplicated(
        candidates,
        excludingBundleIdentifier: excludedBundleIdentifier
      )
    }
    let candidates = try await withTaskCancellationHandler {
      try await scanTask.value
    } onCancel: {
      scanTask.cancel()
    }

    return materializer.materialize(candidates)
  }
}

struct ApplicationCatalogCandidate: Equatable, Sendable {
  let displayName: String
  let bundleIdentifier: String?
  let url: URL
  let sourcePriority: Int
  let isBackgroundOnly: Bool
  let isHelper: Bool
}

protocol ApplicationCatalogLoading {
  @MainActor
  func load() async throws -> [InstalledApplication]
}

private enum ApplicationCatalogError: LocalizedError {
  case unreadableDirectories([URL])

  var errorDescription: String? {
    switch self {
    case let .unreadableDirectories(directories):
      let names = directories.map(\.path).joined(separator: ", ")
      return "Couldn’t read application directories: \(names)"
    }
  }
}
