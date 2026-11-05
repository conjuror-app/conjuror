import Foundation
import Testing

@testable import Conjuror

@Suite("Quicklink Matcher")
struct QuicklinkMatcherTests {
  private let github = Quicklink(
    name: "GitHub",
    keyword: "gh",
    urlTemplate: "https://github.com/search?q={query}"
  )
  private let wikipedia = Quicklink(
    name: "Wikipedia",
    keyword: "wiki",
    urlTemplate: "https://en.wikipedia.org/w/index.php?search={query}"
  )

  private var matcher: QuicklinkMatcher {
    QuicklinkMatcher(quicklinks: [github, wikipedia])
  }

  @Test("The first word matches a keyword, ignoring case, and the rest is the search text")
  func testKeywordWithSearchText() {
    #expect(
      matcher.keywordMatch(for: "  GH swift testing ")
        == QuicklinkMatcher.Match(quicklink: github, argument: "swift testing")
    )
    #expect(
      matcher.keywordMatch(for: "gh") == QuicklinkMatcher.Match(quicklink: github, argument: "")
    )
  }

  @Test("A keyword must be the whole first word")
  func testKeywordMustBeWholeWord() {
    #expect(matcher.keywordMatch(for: "ghost") == nil)
    #expect(matcher.keywordMatch(for: "swift gh") == nil)
  }

  @Test("Names match by prefix but not by fuzzy subsequence")
  func testNameMatchesSkipFuzzyMatches() {
    #expect(matcher.nameMatches(for: "git", recency: [:]) == [github])
    #expect(matcher.nameMatches(for: "gthb", recency: [:]).isEmpty)
    #expect(matcher.nameMatches(for: "git", recency: [:], excluding: github.id).isEmpty)
  }
}
