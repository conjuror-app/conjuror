import AppKit
import XCTest

@testable import Conjuror

final class ShortcutCatalogTests: XCTestCase {
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

    XCTAssertEqual(
      shortcuts,
      [
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

  func testRunScriptUsesTheShortcutIdentifierDirectly() {
    let script = ShortcutsEventsBridge.runScript(identifier: "shortcut-id")

    XCTAssertTrue(script.contains("run shortcut id \"shortcut-id\""))
    XCTAssertFalse(script.contains("first shortcut"))
  }

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

    XCTAssertEqual(
      ShortcutCatalog.excludingInputShortcuts([requiresInput, eligible]),
      [eligible]
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
