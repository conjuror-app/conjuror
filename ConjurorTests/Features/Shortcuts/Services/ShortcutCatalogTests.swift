import AppKit
import Testing

@testable import Conjuror

@Suite("Shortcut Catalog")
struct ShortcutCatalogTests {
  @Test("Shortcut catalog: normal launches do not enter helper mode")
  func testNormalLaunchDoesNotEnterHelperMode() {
    #expect(ShortcutCatalogProcess.runHelperIfRequested(arguments: ["Conjuror"]) == nil)
  }

  @Test("Shortcut catalog: helper responses exclude shortcuts that require input")
  func testHelperResponseExcludesShortcutsThatRequireInput() throws {
    let supported = AppleShortcut(
      id: "supported-id",
      name: "Lights",
      subtitle: "2 actions",
      acceptsInput: false
    )
    let requiresInput = AppleShortcut(
      id: "input-id",
      name: "Share",
      subtitle: "1 action",
      acceptsInput: true
    )

    let data = try ShortcutCatalogProcess.responseData(for: [supported, requiresInput])
    let shortcuts = try ShortcutCatalogProcess.shortcuts(from: data)

    #expect(shortcuts == [supported])
  }

  @Test("Existing caches can contain unused colour and action-count fields")
  func testExistingCache() throws {
    let data = Data(
      #"[{"id":"lights","name":"Lights","subtitle":"","acceptsInput":false,"color":{"red":1,"green":2,"blue":3},"actionCount":2}]"#.utf8
    )

    let shortcuts = try ShortcutCatalogProcess.shortcuts(from: data)

    #expect(shortcuts == [AppleShortcut(id: "lights", name: "Lights", subtitle: "", acceptsInput: false)])
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

  @Test(
    "Shortcut catalog: icons are downsampled with their aspect ratio and alpha",
    arguments: [256, 512]
  )
  func testDownsamplesIcons(height: Int) throws {
    let bitmap = try #require(
      NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: 512,
        pixelsHigh: height,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
      )
    )
    let data = try #require(bitmap.representation(using: .png, properties: [:]))
    let response = NSAppleEventDescriptor.list()
    let record = record(id: "icon-id", name: "Lights", subtitle: "", acceptsInput: false)
    let descriptor = try #require(NSAppleEventDescriptor(descriptorType: 0x504E_4766, data: data))
    record.insert(descriptor, at: 5)
    response.insert(record, at: 1)

    let shortcuts = try ShortcutsEventsBridge.parseShortcutList(response)
    let iconData = try #require(shortcuts.first?.iconData)
    let icon = try #require(NSBitmapImageRep(data: iconData))

    #expect(icon.pixelsWide == 64)
    #expect(icon.pixelsHigh == height / 8)
    #expect(icon.hasAlpha)
  }

  @Test("Shortcut catalog: invalid icons preserve shortcut metadata")
  func testInvalidIconPreservesShortcut() throws {
    let response = NSAppleEventDescriptor.list()
    let record = record(id: "icon-id", name: "Lights", subtitle: "", acceptsInput: false)
    record.insert(NSAppleEventDescriptor(string: "invalid image"), at: 5)
    response.insert(record, at: 1)

    let shortcut = try #require(ShortcutsEventsBridge.parseShortcutList(response).first)

    #expect(shortcut.name == "Lights")
    #expect(shortcut.iconData == nil)
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
