import Foundation
import Testing

@testable import Conjuror

@Suite("File Search Service")
struct FileSearchServiceTests {
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
