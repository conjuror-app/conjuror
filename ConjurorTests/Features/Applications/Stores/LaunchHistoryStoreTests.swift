import AppKit
import Foundation
import XCTest

@testable import Conjuror

final class LaunchHistoryStoreTests: XCTestCase {
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

    XCTAssertEqual(store.load(), [application.persistenceKey: latestDate])
  }

  func testInvalidStoredRepresentationIsIgnored() {
    let userDefaults = makeUserDefaults()
    userDefaults.set(["invalid": "date"], forKey: "recentSuccessfulLaunches")
    let store = LaunchHistoryStore(userDefaults: userDefaults)

    XCTAssertTrue(store.load().isEmpty)
  }

  private func makeUserDefaults() -> UserDefaults {
    let suiteName = "LaunchHistoryStoreTests.\(UUID().uuidString)"
    let userDefaults = UserDefaults(suiteName: suiteName)!
    userDefaults.removePersistentDomain(forName: suiteName)
    return userDefaults
  }
}
