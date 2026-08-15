@preconcurrency import Foundation

enum FileAccessStatus {
  case notChecked
  case granted
  case partiallyGranted
  case denied
}

@MainActor
protocol FileAccessAuthorizing {
  func requestAccess()
}

@MainActor
protocol FileSearching {
  func search(query: String) async throws -> [FileSearchResult]
}

@MainActor
final class FileAccessAuthorizer: ObservableObject, FileAccessAuthorizing {
  @Published private(set) var status = FileAccessStatus.notChecked
  @Published private(set) var unavailableFolders = [String]()

  func requestAccess() {
    let fileManager = FileManager.default
    let directories: [(String, FileManager.SearchPathDirectory)] = [
      ("Desktop", .desktopDirectory),
      ("Documents", .documentDirectory),
      ("Downloads", .downloadsDirectory),
    ]
    unavailableFolders = directories.compactMap { name, directory in
      guard let url = fileManager.urls(for: directory, in: .userDomainMask).first else {
        return name
      }
      do {
        _ = try fileManager.contentsOfDirectory(
          at: url,
          includingPropertiesForKeys: nil,
          options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]
        )
        return nil
      } catch {
        return name
      }
    }

    switch unavailableFolders.count {
    case 0:
      status = .granted
    case directories.count:
      status = .denied
    default:
      status = .partiallyGranted
    }
  }
}

@MainActor
final class SpotlightFileSearchService: FileSearching {
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

    let operation = SpotlightSearchOperation(query: query, limit: Self.resultLimit)
    return await withTaskCancellationHandler {
      await operation.results()
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

@MainActor
private final class SpotlightSearchOperation: @unchecked Sendable {
  private let metadataQuery: NSMetadataQuery
  private let query: String
  private let limit: Int
  private var continuation: CheckedContinuation<[FileSearchResult], Never>?
  private var observer: NSObjectProtocol?

  init(query: String, limit: Int) {
    self.query = query
    self.limit = limit

    let metadataQuery = NSMetadataQuery()
    metadataQuery.searchScopes = [NSMetadataQueryLocalComputerScope]
    metadataQuery.predicate = NSPredicate(
      format: "%K LIKE[cd] %@",
      NSMetadataItemDisplayNameKey,
      "*\(Self.escapedPattern(query))*"
    )
    metadataQuery.sortDescriptors = [
      NSSortDescriptor(
        key: NSMetadataItemDisplayNameKey,
        ascending: true,
        selector: #selector(NSString.localizedStandardCompare(_:))
      )
    ]
    self.metadataQuery = metadataQuery
  }

  private static func escapedPattern(_ value: String) -> String {
    value
      .replacingOccurrences(of: "\\", with: "\\\\")
      .replacingOccurrences(of: "*", with: "\\*")
      .replacingOccurrences(of: "?", with: "\\?")
  }

  func results() async -> [FileSearchResult] {
    guard !Task.isCancelled else { return [] }
    return await withCheckedContinuation { continuation in
      self.continuation = continuation
      observer = NotificationCenter.default.addObserver(
        forName: .NSMetadataQueryDidFinishGathering,
        object: metadataQuery,
        queue: .main
      ) { [weak self] _ in
        MainActor.assumeIsolated {
          self?.finish()
        }
      }
      metadataQuery.start()
    }
  }

  func cancel() {
    complete(with: [])
  }

  private func finish() {
    metadataQuery.disableUpdates()
    let results = (0..<metadataQuery.resultCount).compactMap { index in
      Self.result(from: metadataQuery.result(at: index))
    }
    let rankedResults = FileResultRanker.ranked(results: results, query: query)
    complete(with: Array(rankedResults.prefix(limit)))
  }

  private func complete(with results: [FileSearchResult]) {
    metadataQuery.stop()
    if let observer {
      NotificationCenter.default.removeObserver(observer)
      self.observer = nil
    }
    continuation?.resume(returning: results)
    continuation = nil
  }

  nonisolated private static func result(from value: Any) -> FileSearchResult? {
    guard let item = value as? NSMetadataItem,
      let path = item.value(forAttribute: NSMetadataItemPathKey) as? String
    else { return nil }

    let url = URL(fileURLWithPath: path)
    let resourceValues = try? url.resourceValues(
      forKeys: [.isDirectoryKey, .contentModificationDateKey, .isHiddenKey]
    )
    guard resourceValues?.isHidden != true else { return nil }

    return FileSearchResult(
      url: url,
      displayName: item.value(forAttribute: NSMetadataItemDisplayNameKey) as? String
        ?? url.lastPathComponent,
      isDirectory: resourceValues?.isDirectory ?? false,
      modificationDate: resourceValues?.contentModificationDate
    )
  }
}

private enum FileResultRanker {
  static func ranked(results: [FileSearchResult], query: String) -> [FileSearchResult] {
    let query = normalized(query)
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

  private static func rank(_ result: FileSearchResult, query: String) -> Int {
    let name = normalized(result.displayName)
    if name == query { return 0 }
    if name.hasPrefix(query) { return 1 }
    if name.split(whereSeparator: { !$0.isLetter && !$0.isNumber })
      .contains(where: { $0.hasPrefix(query) })
    {
      return 2
    }
    if name.contains(query) { return 3 }
    return 4
  }

  private static func normalized(_ value: String) -> String {
    value
      .folding(options: .diacriticInsensitive, locale: .current)
      .lowercased()
  }
}
