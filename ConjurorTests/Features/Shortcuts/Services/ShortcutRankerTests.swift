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

    let result = SearchIndex(shortcuts).ranked(
      query: "code",
      recency: [:]
    )

    #expect(result.map(\.id) == ["exact", "prefix", "token", "acronym"])
  }

  @Test("Recent runs break subtitle-match ties")
  func testSubtitleAndRecency() {
    let first = shortcut("Morning", id: "first", subtitle: "Bedroom lights")
    let second = shortcut("Evening", id: "second", subtitle: "Bedroom lights")

    let result = SearchIndex([first, second]).ranked(
      query: "bedroom",
      recency: [second.persistenceKey: Date(timeIntervalSince1970: 20)]
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
