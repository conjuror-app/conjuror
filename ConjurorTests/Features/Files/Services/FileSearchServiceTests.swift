import Foundation
import Testing

@testable import Conjuror

@Suite("File Search Service")
struct FileSearchServiceTests {
  @MainActor
  @Test("ICloud Drive is included")
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
  @Test("Unavailable query reports an error")
  func testUnavailableSpotlight() async {
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
  @Test("Gathering stops at the candidate limit")
  func testCandidateLimit() async throws {
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
  @Test("Stalled query reports a timeout")
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

  @Test("Each word becomes an ordered fuzzy pattern")
  func testFuzzyPatterns() {
    #expect(SpotlightFilenameQuery.patterns(for: "xcd") == ["*x*c*d*"])
    #expect(SpotlightFilenameQuery.patterns(for: "rés umé") == ["*r*e*s*", "*u*m*e*"])
    #expect(SpotlightFilenameQuery.patterns(for: "char games") == ["*c*h*a*r*", "*g*a*m*e*s*"])
  }

  @Test("Wildcard characters are escaped")
  func testEscapedWildcards() {
    #expect(SpotlightFilenameQuery.patterns(for: "*") == ["*\\**"])
    #expect(SpotlightFilenameQuery.patterns(for: "?") == ["*\\?*"])
    #expect(SpotlightFilenameQuery.patterns(for: "\\") == ["*\\\\*"])
  }

  @Test("Single words use a direct predicate")
  func testSingleWordSpotlightPredicateIsDirect() {
    let predicate = SpotlightFilenameQuery.predicate(for: "notes")

    #expect(!(predicate is NSCompoundPredicate))
    #expect(
      predicate.evaluate(
        with: [NSMetadataItemDisplayNameKey: "Meeting Notes.md"]
      )
    )
  }

  @Test("Fuzzy words match across a filename")
  func testFuzzyWords() {
    let predicate = SpotlightFilenameQuery.predicate(for: "char games")

    #expect(
      predicate.evaluate(
        with: [NSMetadataItemDisplayNameKey: "Characteristics of Games.pdf"]
      )
    )
  }

  @Test("Files that don't match the query stay after matches")
  func testUnmatchedFilesFollowMatches() {
    let results = [result("Xylophone"), result("Xcode")]

    let ranked = FileResultRanker.ranked(results: results, query: "xcd")

    #expect(ranked.map(\.displayName) == ["Xcode", "Xylophone"])
  }

  @Test("Existing directory tie-break is preserved")
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
