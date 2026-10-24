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
      URL(fileURLWithPath: "/System/Library/CoreServices/Applications", isDirectory: true),
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
      seenPaths.insert(directory.canonicalFileURL.path).inserted
    }
  }

  static func filteredAndDeduplicated(
    _ candidates: [ApplicationCatalogCandidate]
  ) -> [ApplicationCatalogCandidate] {
    var seenURLs = Set<String>()

    return
      candidates
      .map { (name: SearchText.normalized($0.displayName), candidate: $0) }
      .sorted { lhs, rhs in
        if lhs.candidate.sourcePriority != rhs.candidate.sourcePriority {
          return lhs.candidate.sourcePriority < rhs.candidate.sourcePriority
        }

        if lhs.name != rhs.name { return lhs.name < rhs.name }

        return lhs.candidate.url.path < rhs.candidate.url.path
      }
      .map(\.candidate)
      .filter { candidate in
        !candidate.isBackgroundOnly && !candidate.isHelper
          && seenURLs.insert(candidate.url.canonicalFileURL.path).inserted
      }
  }

  static func installedApplications(
    from candidates: [ApplicationCatalogCandidate]
  ) -> [InstalledApplication] {
    let nameGroups = Dictionary(grouping: candidates) { SearchText.normalized($0.displayName) }

    return candidates.map { candidate in
      let matches = nameGroups[SearchText.normalized(candidate.displayName)] ?? []
      var displayName = candidate.displayName

      if matches.count > 1 {
        let filename = candidate.url.deletingPathExtension().lastPathComponent
        let matchingFilenames = matches.filter {
          SearchText.normalized($0.url.deletingPathExtension().lastPathComponent)
            == SearchText.normalized(filename)
        }

        displayName =
          matchingFilenames.count > 1
          ? "\(filename) (\(candidate.url.deletingLastPathComponent().path))"
          : filename
      }

      return InstalledApplication(
        displayName: displayName,
        bundleIdentifier: candidate.bundleIdentifier,
        url: candidate.url
      )
    }
  }

  static func scan(directories: [URL]) throws -> [ApplicationCatalogCandidate] {
    let fileManager = FileManager.default
    var candidates = [ApplicationCatalogCandidate]()
    var candidatePaths = Set<String>()
    var readableDirectoryCount = 0
    var unreadableDirectories = [URL]()

    func appendCandidate(at url: URL, sourcePriority: Int) throws {
      guard url.pathExtension.caseInsensitiveCompare("app") == .orderedSame else { return }

      try Task.checkCancellation()

      let canonicalURL = url.canonicalFileURL

      guard !candidatePaths.contains(canonicalURL.path),
        let candidate = candidate(
          at: url,
          canonicalURL: canonicalURL,
          sourcePriority: sourcePriority
        )
      else { return }

      candidates.append(candidate)
      candidatePaths.insert(canonicalURL.path)
    }

    for (sourcePriority, directory) in directories.enumerated() {
      try Task.checkCancellation()

      guard fileManager.fileExists(atPath: directory.path) else {
        continue
      }

      let keys: [URLResourceKey] = [.isDirectoryKey, .isPackageKey]

      // Finder hides some top-level app symlinks, including Safari.
      // Scan them separately because the recursive scan skips hidden files.
      let topLevelApplications =
        (try? fileManager.contentsOfDirectory(
          at: directory,
          includingPropertiesForKeys: keys,
          options: []
        )) ?? []
      for url in topLevelApplications {
        try appendCandidate(at: url, sourcePriority: sourcePriority)
      }

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

      for case let url as URL in enumerator {
        try appendCandidate(at: url, sourcePriority: sourcePriority)
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

  private static func candidate(
    at url: URL,
    canonicalURL: URL,
    sourcePriority: Int
  ) -> ApplicationCatalogCandidate? {
    guard let bundle = Bundle(url: url),
      let info = bundle.infoDictionary
    else {
      return nil
    }

    let packageType = info["CFBundlePackageType"] as? String
    let isPasswordsApp =
      bundle.bundleIdentifier == "com.apple.Passwords"
      && packageType == "XPC!"
    // Some apps, including Icon Composer, omit CFBundlePackageType.
    let hasUntypedExecutable =
      packageType == nil
      && bundle.executableURL.map { FileManager.default.isExecutableFile(atPath: $0.path) } == true
    guard packageType == "APPL" || isPasswordsApp || hasUntypedExecutable else {
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
      url: canonicalURL,
      sourcePriority: sourcePriority,
      // LSUIElement apps such as Raycast can be launched. Exclude only background-only apps.
      isBackgroundOnly: info["LSBackgroundOnly"] as? Bool == true,
      isHelper: isHelper
    )
  }

  func load() async throws -> [InstalledApplication] {
    let directories = Self.applicationDirectories()

    let scanTask = Task.detached(priority: .userInitiated) {
      let candidates = try Self.scan(directories: directories)

      return Self.filteredAndDeduplicated(candidates)
    }

    let candidates = try await withTaskCancellationHandler {
      try await scanTask.value
    } onCancel: {
      scanTask.cancel()
    }

    return Self.installedApplications(from: candidates)
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
