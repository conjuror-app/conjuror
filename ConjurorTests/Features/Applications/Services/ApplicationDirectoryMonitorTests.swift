import Foundation
import Testing

@testable import Conjuror

@MainActor
@Suite("Application Directory Monitor")
struct ApplicationDirectoryMonitorTests {
  @Test("Directory changes refresh the catalog after app installation and removal")
  func testInstallationAndRemoval() async throws {
    let fileManager = FileManager.default
    let directory = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let applications = directory.appendingPathComponent("Applications/Tools")
    try fileManager.createDirectory(at: applications, withIntermediateDirectories: true)
    defer { try? fileManager.removeItem(at: directory) }

    var names = [String]()
    let monitor = ApplicationDirectoryMonitor {
      names = (try? ApplicationCatalog.scan(directories: [applications]).map(\.displayName)) ?? []
    }

    defer { monitor.stop() }
    #expect(monitor.start(directories: [directory.appendingPathComponent("Applications")]))

    let app = applications.appendingPathComponent("New App.app")
    let contents = app.appendingPathComponent("Contents")
    try fileManager.createDirectory(at: contents, withIntermediateDirectories: true)
    let info = ["CFBundleName": "New App", "CFBundlePackageType": "APPL"]
    let data = try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0)
    try data.write(to: contents.appendingPathComponent("Info.plist"))
    #expect(await waitUntil { names == ["New App"] })

    try fileManager.removeItem(at: app)
    #expect(await waitUntil { names.isEmpty })
  }

  @Test("Monitoring includes application directories created after startup")
  func testNewApplicationDirectory() async throws {
    let fileManager = FileManager.default
    let directory = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? fileManager.removeItem(at: directory) }

    let applications = directory.appendingPathComponent("Applications")
    var changed = false
    let monitor = ApplicationDirectoryMonitor { changed = true }
    defer { monitor.stop() }
    #expect(monitor.start(directories: [applications]))

    try fileManager.createDirectory(
      at: applications.appendingPathComponent("New App.app"),
      withIntermediateDirectories: true
    )
    #expect(await waitUntil { changed })
  }

  @Test("A stopped monitor can watch a different application directory")
  func testRestart() async throws {
    let fileManager = FileManager.default
    let directory = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let first = directory.appendingPathComponent("First")
    let second = directory.appendingPathComponent("Second")
    try fileManager.createDirectory(at: first, withIntermediateDirectories: true)
    try fileManager.createDirectory(at: second, withIntermediateDirectories: true)
    defer { try? fileManager.removeItem(at: directory) }

    var changed = false
    let monitor = ApplicationDirectoryMonitor { changed = true }
    defer { monitor.stop() }
    #expect(monitor.start(directories: [first]))
    monitor.stop()
    #expect(monitor.start(directories: [second]))
    try fileManager.createDirectory(
      at: second.appendingPathComponent("New App.app"),
      withIntermediateDirectories: true
    )
    #expect(await waitUntil { changed })
  }

  private func waitUntil(_ condition: () -> Bool) async -> Bool {
    let deadline = ContinuousClock.now.advanced(by: .seconds(5))

    while !condition(), ContinuousClock.now < deadline {
      try? await Task.sleep(for: .milliseconds(50))
    }

    return condition()
  }
}
