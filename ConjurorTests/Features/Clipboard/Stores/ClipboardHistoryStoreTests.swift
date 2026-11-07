import Foundation
import Testing

@testable import Conjuror

@MainActor
@Suite("Clipboard history store")
struct ClipboardHistoryStoreTests {
  @Test("Copying text again moves it to the top without duplicating it")
  func testDuplicateMovesToTop() {
    let clock = TestClock()
    let store = ClipboardHistoryStore(fileURL: nil, now: clock.now)
    let safari = ClipboardSource(name: "Safari", bundleIdentifier: "com.apple.Safari")

    store.record("first", source: safari)
    clock.advance(by: 60)
    store.record("second", source: nil)
    clock.advance(by: 60)
    store.record("first", source: nil)

    #expect(store.items.map(\.text) == ["first", "second"])
    #expect(store.items.first?.source == safari)
    #expect(store.items.first?.lastCopiedAt == clock.date)
  }

  @Test("Keeps history across launches")
  func testPersistence() throws {
    let fileURL = temporaryFileURL()
    defer { try? FileManager.default.removeItem(at: fileURL.deletingLastPathComponent()) }

    let store = ClipboardHistoryStore(fileURL: fileURL)
    store.record("kept", source: nil)

    #expect(ClipboardHistoryStore(fileURL: fileURL).items.map(\.text) == ["kept"])

    let permissions =
      try FileManager.default.attributesOfItem(atPath: fileURL.path)[
        .posixPermissions
      ] as? Int
    #expect(permissions == 0o600)
  }

  @Test("Clearing history deletes its file")
  func testRemoveAll() {
    let fileURL = temporaryFileURL()
    defer { try? FileManager.default.removeItem(at: fileURL.deletingLastPathComponent()) }

    let store = ClipboardHistoryStore(fileURL: fileURL)
    store.record("gone", source: nil)
    store.removeAll()

    #expect(store.items.isEmpty)
    #expect(!FileManager.default.fileExists(atPath: fileURL.path))
  }

  @Test("Removes items older than the retention period")
  func testRetention() {
    let clock = TestClock()
    let store = ClipboardHistoryStore(fileURL: nil, now: clock.now)

    store.record("old", source: nil)
    clock.advance(by: 2 * 24 * 60 * 60)
    store.record("new", source: nil)
    store.setRetention(.day)

    #expect(store.items.map(\.text) == ["new"])
  }

  @Test("Keeps only the newest items past the limit")
  func testItemLimit() {
    let store = ClipboardHistoryStore(fileURL: nil)

    for index in 0...ClipboardHistoryStore.maximumItemCount {
      store.record("item \(index)", source: nil)
    }

    #expect(store.items.count == ClipboardHistoryStore.maximumItemCount)
    #expect(store.items.first?.text == "item \(ClipboardHistoryStore.maximumItemCount)")
    #expect(store.items.last?.text == "item 1")
  }

  private func temporaryFileURL() -> URL {
    FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
      .appendingPathComponent("clipboard-history.json")
  }
}

final class TestClock {
  private(set) var date = Date(timeIntervalSince1970: 1_800_000_000)

  func now() -> Date { date }

  func advance(by interval: TimeInterval) {
    date += interval
  }
}
