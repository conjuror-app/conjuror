import AppKit
import Foundation
import Testing

@testable import Conjuror

@Suite("Launch History Store")
struct LaunchHistoryStoreTests {
  @Test("Launch history store: invalid stored representations are ignored")
  func testInvalidStoredRepresentationIsIgnored() {
    let userDefaults = makeUserDefaults()
    userDefaults.set(["invalid": "date"], forKey: "recentSuccessfulLaunches")
    let store = LaunchHistoryStore(userDefaults: userDefaults)

    #expect(store.load().isEmpty)
  }

  @Test("Launch history store: most recent successful launches are recorded and reloaded")
  func testRecordsAndReloadsMostRecentSuccessfulLaunch() {
    let store = LaunchHistoryStore(userDefaults: makeUserDefaults())
    let application = InstalledApplication(
      displayName: "Alpha",
      bundleIdentifier: "dev.example.alpha",
      url: URL(fileURLWithPath: "/Applications/Alpha.app"),
      icon: NSImage(size: NSSize(width: 32, height: 32))
    )
    let firstDate = Date(timeIntervalSince1970: 10)
    let latestDate = Date(timeIntervalSince1970: 20)

    store.recordLaunch(of: application, at: firstDate)
    store.recordLaunch(of: application, at: latestDate)

    #expect(store.load() == [application.persistenceKey: latestDate])
  }

  private func makeUserDefaults() -> UserDefaults {
    let suiteName = "LaunchHistoryStoreTests.\(UUID().uuidString)"
    let userDefaults = UserDefaults(suiteName: suiteName)!
    userDefaults.removePersistentDomain(forName: suiteName)
    return userDefaults
  }
}
