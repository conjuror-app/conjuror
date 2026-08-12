import Foundation
import Testing

@testable import Conjuror

@Suite("Shortcut Ranker")
struct ShortcutRankerTests {
  @Test("Shortcut ranking: names follow launcher matching rules")
  func testRanksNamesUsingLauncherMatchingRules() {
    let shortcuts = [
      shortcut("Very Special Code", id: "acronym"),
      shortcut("Code Runner", id: "prefix"),
      shortcut("Code", id: "exact"),
      shortcut("Studio Code", id: "token"),
    ]

    let result = ShortcutRanker.ranked(
      shortcuts: shortcuts,
      query: "code",
      recentRuns: [:]
    )

    #expect(result.map(\.id) == ["exact", "prefix", "token", "acronym"])
  }

  @Test("Shortcut ranking: subtitle matches and recent runs rank empty queries")
  func testMatchesSubtitleAndUsesRecentRunsForEmptyQuery() {
    let first = shortcut("Morning", id: "first", subtitle: "Bedroom lights")
    let second = shortcut("Evening", id: "second", subtitle: "Bedroom lights")

    let result = ShortcutRanker.ranked(
      shortcuts: [first, second],
      query: "bedroom",
      recentRuns: [second.persistenceKey: Date(timeIntervalSince1970: 20)]
    )

    #expect(result == [second, first])
  }

  @Test("Shortcut ranking: fuzzy subsequences match shortcut names")
  func testFuzzySubsequenceMatchesShortcutName() {
    let shortcuts = [
      shortcut("Xylophone", id: "other"),
      shortcut("Xcode", id: "match"),
    ]

    let result = ShortcutRanker.ranked(
      shortcuts: shortcuts,
      query: "xcd",
      recentRuns: [:]
    )

    #expect(result.map(\.id) == ["match"])
  }

  private func shortcut(
    _ name: String,
    id: String,
    subtitle: String = ""
  ) -> AppleShortcut {
    AppleShortcut(id: id, name: name, subtitle: subtitle, acceptsInput: false)
  }
}
