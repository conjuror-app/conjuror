import Foundation
import Testing

@testable import Conjuror

@Suite("Quicklink")
struct QuicklinkTests {
  @Test("Search text is percent-encoded so it is safe in a path or a query")
  func testEncodesSearchTextForAnyPosition() {
    let quicklink = Quicklink(
      name: "Example",
      urlTemplate: "https://example.com/s/{query}?q={query}"
    )
    let encoded = "a%26b%3Dc%20%231%20%2B%C3%A9%2F%F0%9F%99%82"

    #expect(
      quicklink.url(argument: "  a&b=c #1 +é/🙂 ")?.absoluteString
        == "https://example.com/s/\(encoded)?q=\(encoded)"
    )
  }

  @Test("Templates without a placeholder ignore search text, and templates need a scheme")
  func testTemplatesWithoutPlaceholderOrScheme() {
    let plain = Quicklink(name: "Calendar", urlTemplate: "https://calendar.example.com/week")
    let schemeless = Quicklink(name: "Example", urlTemplate: "example.com/?q={query}")

    #expect(plain.url(argument: "ignored")?.absoluteString == "https://calendar.example.com/week")
    #expect(schemeless.url(argument: "swift") == nil)
  }

  @Test("Validation rejects keywords the launcher can't match and URLs it can't open")
  func testValidation() {
    let github = Quicklink(name: "GitHub", keyword: "gh", urlTemplate: "https://github.com")
    let existing = [github]

    func error(keyword: String?, url: String = "https://example.com") -> String? {
      Quicklink.validationError(
        for: Quicklink(name: "Example", keyword: keyword, urlTemplate: url),
        among: existing
      )
    }

    #expect(error(keyword: "GH") == "Another quicklink already uses “GH”.")
    #expect(error(keyword: "g h") == "Keywords can’t contain spaces.")
    #expect(error(keyword: "!gh") == "Keywords can’t start with ;, >, :, /, ! or @.")
    #expect(error(keyword: "ex", url: "example.com") != nil)
    #expect(error(keyword: " ex ") == nil)
    #expect(Quicklink.validationError(for: github, among: existing) == nil)
  }
}
