import AppKit
import Testing

@testable import Conjuror

@Suite("Shortcut Catalog")
struct ShortcutCatalogTests {
  @Test("Shortcut catalog: shortcuts that accept input are excluded")
  func testExcludesShortcutsThatAcceptInput() {
    let eligible = AppleShortcut(
      id: "eligible",
      name: "Lights",
      subtitle: "",
      acceptsInput: false
    )
    let requiresInput = AppleShortcut(
      id: "input",
      name: "Share",
      subtitle: "",
      acceptsInput: true
    )

    #expect(ShortcutCatalog.excludingInputShortcuts([requiresInput, eligible]) == [eligible])
  }

  @Test("Shortcut catalog: shortcut identifiers are passed directly to run scripts")
  func testRunScriptUsesTheShortcutIdentifierDirectly() {
    let script = ShortcutsEventsBridge.runScript(identifier: "shortcut-id")

    #expect(script.contains("run shortcut id \"shortcut-id\""))
    #expect(!(script.contains("first shortcut")))
  }

  @Test("Shortcut catalog: structured Shortcuts Events responses are parsed")
  func testParsesStructuredShortcutsEventsResponse() throws {
    let response = NSAppleEventDescriptor.list()
    response.insert(
      record(id: "first-id", name: "Lights", subtitle: "2 actions", acceptsInput: false),
      at: 1
    )
    response.insert(
      record(id: "second-id", name: "Share", subtitle: "1 action", acceptsInput: true),
      at: 2
    )

    let shortcuts = try ShortcutsEventsBridge.parseShortcutList(response)

    #expect(
      shortcuts == [
        AppleShortcut(
          id: "first-id",
          name: "Lights",
          subtitle: "2 actions",
          acceptsInput: false
        ),
        AppleShortcut(
          id: "second-id",
          name: "Share",
          subtitle: "1 action",
          acceptsInput: true
        ),
      ]
    )
  }

  private func record(
    id: String,
    name: String,
    subtitle: String,
    acceptsInput: Bool
  ) -> NSAppleEventDescriptor {
    let record = NSAppleEventDescriptor.list()
    record.insert(NSAppleEventDescriptor(string: id), at: 1)
    record.insert(NSAppleEventDescriptor(string: name), at: 2)
    record.insert(NSAppleEventDescriptor(string: subtitle), at: 3)
    record.insert(NSAppleEventDescriptor(boolean: acceptsInput), at: 4)
    return record
  }
}
