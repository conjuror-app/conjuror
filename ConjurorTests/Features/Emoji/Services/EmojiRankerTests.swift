import Testing

@testable import Conjuror

@Suite("Emoji Ranker")
struct EmojiRankerTests {
  @Test("Recognizes explicit skin-tone searches")
  func testRecognizesExplicitSkinToneQueries() {
    #expect(EmojiRanker.explicitlyRequestsSkinTone("medium-dark skin tone"))
    #expect(!EmojiRanker.explicitlyRequestsSkinTone("waving hand"))
  }

  @Test("Emoji ranking: CLDR keywords match emoji")
  func testCLDRKeywordsMatchEmoji() throws {
    let emoji = try #require(Emoji.catalog.first { $0.value == "😂" })

    #expect(emoji.keywords.contains("lol"))
    #expect(EmojiRanker.Index(emoji: [emoji]).ranked(query: "lol") == [emoji])
  }

  @Test("Emoji ranking: Unicode names rank before keyword matches")
  func testNamesRankBeforeKeywords() {
    let namedMatch = Emoji(
      value: "🐕",
      name: "dog",
      category: "Animals & Nature",
      keywords: []
    )
    let keywordMatch = Emoji(
      value: "🐶",
      name: "puppy face",
      category: "Animals & Nature",
      keywords: ["dog"]
    )

    let result = EmojiRanker.Index(emoji: [keywordMatch, namedMatch]).ranked(query: "dog")

    #expect(result == [namedMatch, keywordMatch])
  }
}
