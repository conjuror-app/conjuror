import Foundation
import Testing

@testable import Conjuror

@Suite("Shortcut Ranker")
struct ShortcutRankerTests {
  @Test("Names follow launcher matching rules")
  func testRanksNamesUsingLauncherMatchingRules() {
    let shortcuts = [
      shortcut("Very Special Code", id: "acronym"),
      shortcut("Code Runner", id: "prefix"),
      shortcut("Code", id: "exact"),
      shortcut("Studio Code", id: "token"),
    ]

    let result = ShortcutRanker.Index(shortcuts: shortcuts).ranked(
      query: "code",
      recentRuns: [:]
    )

    #expect(result.map(\.id) == ["exact", "prefix", "token", "acronym"])
  }

  @Test("Recent runs break subtitle-match ties")
  func testSubtitleAndRecency() {
    let first = shortcut("Morning", id: "first", subtitle: "Bedroom lights")
    let second = shortcut("Evening", id: "second", subtitle: "Bedroom lights")

    let result = ShortcutRanker.Index(shortcuts: [first, second]).ranked(
      query: "bedroom",
      recentRuns: [second.persistenceKey: Date(timeIntervalSince1970: 20)]
    )

    #expect(result == [second, first])
  }

  private func shortcut(
    _ name: String,
    id: String,
    subtitle: String = ""
  ) -> AppleShortcut {
    AppleShortcut(id: id, name: name, subtitle: subtitle, acceptsInput: false)
  }
}
