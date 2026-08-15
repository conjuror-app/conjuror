import AppKit
import Foundation
import Testing

@testable import Conjuror

@Suite("Launch History Store")
struct LaunchHistoryStoreTests {
  @Test("Launch history store: invalid stored representations are ignored")
  func testInvalidStoredRepresentationIsIgnored() {
    let userDefaults = makeTestUserDefaults()
    userDefaults.set(["invalid": "date"], forKey: "recentSuccessfulLaunches")
    let store = LaunchHistoryStore(userDefaults: userDefaults)

    #expect(store.load().isEmpty)
  }

  @Test("Launch history store: most recent successful launches are recorded and reloaded")
  func testRecordsAndReloadsMostRecentSuccessfulLaunch() {
    let store = LaunchHistoryStore(userDefaults: makeTestUserDefaults())
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

  @Test("Launch history store: only the 100 most recent launches are retained")
  func testLimitsHistoryToMostRecentLaunches() {
    let userDefaults = makeTestUserDefaults()
    let store = LaunchHistoryStore(userDefaults: userDefaults)

    for index in 0..<101 {
      let application = InstalledApplication(
        displayName: "Application \(index)",
        bundleIdentifier: "dev.example.application-\(index)",
        url: URL(fileURLWithPath: "/Applications/Application-\(index).app"),
        icon: NSImage(size: NSSize(width: 32, height: 32))
      )
      store.recordLaunch(of: application, at: Date(timeIntervalSince1970: Double(index)))
    }

    let history = store.load()
    #expect(history.count == 100)
    #expect(userDefaults.dictionary(forKey: "recentSuccessfulLaunches")?.count == 100)
    #expect(history["dev.example.application-0"] == nil)
    #expect(history["dev.example.application-100"] != nil)
  }

  private func makeTestUserDefaults() -> UserDefaults {
    let suiteName = "LaunchHistoryStoreTests.\(UUID().uuidString)"
    let userDefaults = UserDefaults(suiteName: suiteName)!
    userDefaults.removePersistentDomain(forName: suiteName)
    return userDefaults
  }
}
