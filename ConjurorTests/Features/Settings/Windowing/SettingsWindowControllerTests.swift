import AppKit
import Testing

@testable import Conjuror

@MainActor
@Suite("Settings Window Controller")
struct SettingsWindowControllerTests {
  @Test("Settings window controller: closing releases content and allows recreation")
  func testCloseAndReopen() throws {
    let settings = SettingsStore(userDefaults: makeTestUserDefaults())
    let hotKeys = HotKeyStore(settingsStore: settings, onHotKeyPressed: { _ in })
    let currencyRates = CurrencyRateStore(userDefaults: makeTestUserDefaults())
    let launchAtLogin = LaunchAtLoginStore()
    var controller: SettingsWindowController?
    weak var closedController: SettingsWindowController?
    weak var closedContent: NSViewController?

    for _ in 0..<2 {
      try autoreleasepool {
        controller = SettingsWindowController(
          store: settings,
          hotKeyStore: hotKeys,
          currencyRateStore: currencyRates,
          launchAtLoginStore: launchAtLogin,
          onClose: { controller = nil }
        )
        closedController = controller
        let window = try #require(controller?.window)
        closedContent = try #require(window.contentViewController)

        // Keep the key window available to the launcher keyboard tests.
        window.orderBack(nil)
        #expect(window.isVisible)
        window.performClose(nil)

        #expect(!window.isVisible)
        #expect(window.contentViewController == nil)
        #expect(controller == nil)
      }
      #expect(closedController == nil)
      #expect(closedContent == nil)
    }
  }
}
