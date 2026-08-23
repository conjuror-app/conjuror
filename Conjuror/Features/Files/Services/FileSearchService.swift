@preconcurrency import Foundation

@MainActor
protocol FileAccessAuthorizing {
  func requestAccess()
}

@MainActor
protocol FileSearching {
  func search(query: String) async throws -> [FileSearchResult]
}

@MainActor
final class FileAccessAuthorizer: FileAccessAuthorizing {
  static func authorizationDirectories(fileManager: FileManager = .default) -> [URL] {
    let protectedDirectories: [FileManager.SearchPathDirectory] = [
      .desktopDirectory,
      .documentDirectory,
      .downloadsDirectory,
    ]
    let localDirectories = protectedDirectories.compactMap { directory in
      fileManager.urls(for: directory, in: .userDomainMask).first
    }
    let iCloudDrive = fileManager.homeDirectoryForCurrentUser.appendingPathComponent(
      "Library/Mobile Documents/com~apple~CloudDocs",
      isDirectory: true
    )
    return localDirectories + [iCloudDrive]
  }

  func requestAccess() {
    let directories = Self.authorizationDirectories()
    Task.detached {
      let fileManager = FileManager.default
      for directory in directories {
        _ = try? fileManager.contentsOfDirectory(
          at: directory,
          includingPropertiesForKeys: nil,
          options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]
        )
      }
    }
  }
}

@MainActor
final class SpotlightFileSearchService: FileSearching {
  private static let candidateLimit = 1_000
  private static let gatheringDeadline = Duration.milliseconds(500)
  private static let resultLimit = 200

  private let accessAuthorizer: FileAccessAuthorizing
  private var didRequestAccess = false

  init(accessAuthorizer: FileAccessAuthorizing = FileAccessAuthorizer()) {
    self.accessAuthorizer = accessAuthorizer
  }

  func search(query: String) async throws -> [FileSearchResult] {
    let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !query.isEmpty else { return [] }

    requestAccessIfNeeded()

    let operation = SpotlightSearchOperation(
      query: query,
      limit: Self.resultLimit,
      candidateLimit: Self.candidateLimit,
      gatheringDeadline: Self.gatheringDeadline
    )
    return try await withTaskCancellationHandler {
      try await operation.results()
    } onCancel: {
      Task { @MainActor in operation.cancel() }
    }
  }

  private func requestAccessIfNeeded() {
    guard !didRequestAccess else { return }
    didRequestAccess = true
    accessAuthorizer.requestAccess()
  }
}

enum SpotlightFileSearchError: LocalizedError, Equatable {
  case timedOut
  case unavailable

  var errorDescription: String? {
    switch self {
    case .timedOut:
      "Spotlight took too long to respond."
    case .unavailable:
      "Spotlight file search is unavailable."
    }
  }
}

@MainActor
final class SpotlightSearchOperation: @unchecked Sendable {
  private let metadataQuery: NSMetadataQuery
  private let query: String
  private let limit: Int
  private let candidateLimit: Int
  private let gatheringDeadline: Duration
  private var continuation: CheckedContinuation<[FileSearchResult], Error>?
  private var observers = [NSObjectProtocol]()
  private var deadlineTask: Task<Void, Never>?

  init(
    query: String,
    limit: Int,
    candidateLimit: Int,
    gatheringDeadline: Duration,
    metadataQuery: NSMetadataQuery = NSMetadataQuery()
  ) {
    self.query = query
    self.limit = limit
    self.candidateLimit = candidateLimit
    self.gatheringDeadline = gatheringDeadline
    self.metadataQuery = metadataQuery

    metadataQuery.searchScopes = [NSMetadataQueryLocalComputerScope]
    metadataQuery.predicate = SpotlightFilenameQuery.predicate(for: query)
    metadataQuery.notificationBatchingInterval = 0.05
  }

  func results() async throws -> [FileSearchResult] {
    guard !Task.isCancelled else { throw CancellationError() }
    return try await withCheckedThrowingContinuation { continuation in
      self.continuation = continuation
      let notificationCenter = NotificationCenter.default
      observers = [
        notificationCenter.addObserver(
          forName: .NSMetadataQueryDidFinishGathering,
          object: metadataQuery,
          queue: .main
        ) { [weak self] _ in
          MainActor.assumeIsolated {
            self?.finish()
          }
        },
        notificationCenter.addObserver(
          forName: .NSMetadataQueryGatheringProgress,
          object: metadataQuery,
          queue: .main
        ) { [weak self] _ in
          MainActor.assumeIsolated {
            self?.finishIfCandidateLimitReached()
          }
        },
      ]

      guard metadataQuery.start() else {
        complete(with: .failure(SpotlightFileSearchError.unavailable))
        return
      }

      let gatheringDeadline = gatheringDeadline
      deadlineTask = Task { @MainActor [weak self] in
        try? await Task.sleep(for: gatheringDeadline)
        guard !Task.isCancelled, let self else { return }
        guard metadataQuery.resultCount > 0 else {
          complete(with: .failure(SpotlightFileSearchError.timedOut))
          return
        }
        finish()
      }
    }
  }

  func cancel() {
    complete(with: .failure(CancellationError()))
  }

  private func finishIfCandidateLimitReached() {
    guard metadataQuery.resultCount >= candidateLimit else { return }
    finish()
  }

  private func finish() {
    guard continuation != nil else { return }
    metadataQuery.disableUpdates()
    let candidateCount = min(metadataQuery.resultCount, candidateLimit)
    let results = (0..<candidateCount).compactMap { index in
      Self.result(from: metadataQuery.result(at: index))
    }
    let rankedResults = FileResultRanker.ranked(results: results, query: query)
    complete(with: .success(Array(rankedResults.prefix(limit))))
  }

  private func complete(with result: Result<[FileSearchResult], Error>) {
    guard let continuation else { return }
    self.continuation = nil
    deadlineTask?.cancel()
    deadlineTask = nil
    metadataQuery.stop()
    observers.forEach(NotificationCenter.default.removeObserver)
    observers.removeAll()
    continuation.resume(with: result)
  }

  nonisolated private static func result(from value: Any) -> FileSearchResult? {
    guard let item = value as? NSMetadataItem,
      let path = item.value(forAttribute: NSMetadataItemPathKey) as? String
    else { return nil }

    let url = URL(fileURLWithPath: path)
    guard item.value(forAttribute: "kMDItemFSInvisible") as? Bool != true else { return nil }
    let contentTypeTree = item.value(forAttribute: "kMDItemContentTypeTree") as? [String]

    return FileSearchResult(
      url: url,
      displayName: item.value(forAttribute: NSMetadataItemDisplayNameKey) as? String
        ?? url.lastPathComponent,
      isDirectory: contentTypeTree?.contains("public.folder") ?? false,
      modificationDate: item.value(forAttribute: "kMDItemContentModificationDate") as? Date
    )
  }
}

enum SpotlightFilenameQuery {
  static func predicate(for query: String) -> NSPredicate {
    let predicates = patterns(for: query).map { pattern in
      NSPredicate(
        format: "%K LIKE[cd] %@",
        NSMetadataItemDisplayNameKey,
        pattern
      )
    }
    if predicates.count == 1 {
      return predicates[0]
    }
    return NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
  }

  static func patterns(for query: String) -> [String] {
    let normalizedQuery = SearchText.normalized(query)
    let tokens = SearchText.tokens(in: normalizedQuery)
    let fuzzyTerms = tokens.isEmpty ? [normalizedQuery] : tokens
    return fuzzyTerms.map { term in
      "*" + term.map { escapedPattern(String($0)) }.joined(separator: "*") + "*"
    }
  }

  private static func escapedPattern(_ value: String) -> String {
    value
      .replacingOccurrences(of: "\\", with: "\\\\")
      .replacingOccurrences(of: "*", with: "\\*")
      .replacingOccurrences(of: "?", with: "\\?")
  }
}

enum FileResultRanker {
  static func ranked(results: [FileSearchResult], query: String) -> [FileSearchResult] {
    let query = SearchText.normalized(query)
    return results.sorted { lhs, rhs in
      let lhsRank = rank(lhs, query: query)
      let rhsRank = rank(rhs, query: query)
      if lhsRank != rhsRank { return lhsRank < rhsRank }
      if lhs.isDirectory != rhs.isDirectory { return lhs.isDirectory }
      if lhs.modificationDate != rhs.modificationDate {
        return (lhs.modificationDate ?? .distantPast)
          > (rhs.modificationDate ?? .distantPast)
      }
      return lhs.url.path.localizedStandardCompare(rhs.url.path) == .orderedAscending
    }
  }

  private static func rank(_ result: FileSearchResult, query: String) -> FileResultRank {
    let name = SearchText.normalized(result.displayName)
    if name == query { return FileResultRank(category: 0) }
    if name.hasPrefix(query) { return FileResultRank(category: 1) }
    if SearchText.tokens(in: name).contains(where: { $0.hasPrefix(query) }) {
      return FileResultRank(category: 2)
    }
    if name.contains(query) { return FileResultRank(category: 3) }

    let compactQuery = SearchText.tokens(in: query).joined()
    let compactName = SearchText.tokens(in: name).joined()
    if let score = SearchText.subsequenceScore(of: compactQuery, in: compactName) {
      return FileResultRank(category: 4, score: score)
    }
    return FileResultRank(category: 5)
  }
}

private struct FileResultRank: Equatable, Comparable {
  static func < (lhs: FileResultRank, rhs: FileResultRank) -> Bool {
    lhs.category == rhs.category ? lhs.score < rhs.score : lhs.category < rhs.category
  }

  let category: Int
  var score = 0
}
