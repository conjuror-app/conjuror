import Foundation
import Testing

@testable import Conjuror

@Suite("File Search Service")
struct FileSearchServiceTests {
  @MainActor
  @Test("File access: iCloud Drive is included")
  func testFileAccessIncludesICloudDrive() {
    let fileManager = FileManager.default
    let expectedURL = fileManager.homeDirectoryForCurrentUser.appendingPathComponent(
      "Library/Mobile Documents/com~apple~CloudDocs",
      isDirectory: true
    )

    #expect(
      FileAccessAuthorizer.authorizationDirectories(fileManager: fileManager).contains(expectedURL)
    )
  }

  @MainActor
  @Test("Spotlight search: unavailable query reports an error")
  func testUnavailableSpotlightQueryReportsError() async {
    let metadataQuery = MetadataQueryStub()
    metadataQuery.startResult = false
    let operation = SpotlightSearchOperation(
      query: "notes",
      limit: 200,
      candidateLimit: 1_000,
      gatheringDeadline: .seconds(1),
      metadataQuery: metadataQuery
    )

    do {
      _ = try await operation.results()
      Issue.record("Expected unavailable Spotlight error")
    } catch let error as SpotlightFileSearchError {
      #expect(error == .unavailable)
    } catch {
      Issue.record("Unexpected error: \(error)")
    }

    #expect(metadataQuery.didStop)
  }

  @MainActor
  @Test("Spotlight search: gathering stops at the candidate limit")
  func testSpotlightGatheringStopsAtCandidateLimit() async throws {
    let metadataQuery = MetadataQueryStub()
    let operation = SpotlightSearchOperation(
      query: "notes",
      limit: 200,
      candidateLimit: 1,
      gatheringDeadline: .seconds(1),
      metadataQuery: metadataQuery
    )
    let resultsTask = Task { try await operation.results() }
    while !metadataQuery.didStart {
      await Task.yield()
    }

    metadataQuery.stubResultCount = 1
    NotificationCenter.default.post(
      name: .NSMetadataQueryGatheringProgress,
      object: metadataQuery
    )
    let results = try await resultsTask.value

    #expect(results.isEmpty)
    #expect(metadataQuery.didDisableUpdates)
    #expect(metadataQuery.didStop)
  }

  @MainActor
  @Test("Spotlight search: stalled query reports a timeout")
  func testStalledSpotlightQueryReportsTimeout() async {
    let metadataQuery = MetadataQueryStub()
    let operation = SpotlightSearchOperation(
      query: "notes",
      limit: 200,
      candidateLimit: 1_000,
      gatheringDeadline: .milliseconds(10),
      metadataQuery: metadataQuery
    )

    do {
      _ = try await operation.results()
      Issue.record("Expected Spotlight timeout error")
    } catch let error as SpotlightFileSearchError {
      #expect(error == .timedOut)
    } catch {
      Issue.record("Unexpected error: \(error)")
    }

    #expect(metadataQuery.didStop)
  }

  @Test("Spotlight filename query: characters become an ordered fuzzy pattern")
  func testSpotlightPatternUsesOrderedCharacters() {
    #expect(SpotlightFilenameQuery.pattern(for: "xcd") == "*x*c*d*")
    #expect(SpotlightFilenameQuery.pattern(for: "rés umé") == "*r*e*s*u*m*e*")
  }

  @Test("Spotlight filename query: wildcard characters are escaped")
  func testSpotlightPatternEscapesWildcardCharacters() {
    #expect(SpotlightFilenameQuery.pattern(for: "*") == "*\\**")
    #expect(SpotlightFilenameQuery.pattern(for: "?") == "*\\?*")
    #expect(SpotlightFilenameQuery.pattern(for: "\\") == "*\\\\*")
  }

  @Test("File ranking: fuzzy subsequences match filenames")
  func testFuzzySubsequenceMatchesFilename() {
    let results = [result("Xylophone"), result("Xcode")]

    let ranked = FileResultRanker.ranked(results: results, query: "xcd")

    #expect(ranked.map(\.displayName) == ["Xcode", "Xylophone"])
  }

  @Test("File ranking: compact fuzzy matches rank first")
  func testCompactFuzzyMatchesRankFirst() {
    let results = [result("Xylocardial"), result("Xcode")]

    let ranked = FileResultRanker.ranked(results: results, query: "xcd")

    #expect(ranked.map(\.displayName) == ["Xcode", "Xylocardial"])
  }

  @Test("File ranking: existing directory tie-break is preserved")
  func testDirectoryTieBreakIsPreserved() {
    let results = [
      result("Alpha file", isDirectory: false), result("Alpha folder", isDirectory: true),
    ]

    let ranked = FileResultRanker.ranked(results: results, query: "alpha")

    #expect(ranked.map(\.isDirectory) == [true, false])
  }

  private func result(_ name: String, isDirectory: Bool = false) -> FileSearchResult {
    FileSearchResult(
      url: URL(fileURLWithPath: "/tmp/\(name)"),
      displayName: name,
      isDirectory: isDirectory,
      modificationDate: nil
    )
  }
}

private final class MetadataQueryStub: NSMetadataQuery {
  var startResult = true
  var stubResultCount = 0
  private(set) var didDisableUpdates = false
  private(set) var didStart = false
  private(set) var didStop = false

  override var resultCount: Int {
    stubResultCount
  }

  override func start() -> Bool {
    didStart = true
    return startResult
  }

  override func stop() {
    didStop = true
  }

  override func disableUpdates() {
    didDisableUpdates = true
  }

  override func result(at index: Int) -> Any {
    NSObject()
  }
}
