import AppKit
import CryptoKit
import Foundation
import Testing

@testable import Conjuror

@MainActor
@Suite("Clipboard History")
struct ClipboardHistoryTests {
  @Test("Clipboard history: preserves text and deduplicates exact matches")
  func testRecordsAndDeduplicatesText() {
    let persistence = ClipboardHistoryPersistenceStub()
    var now = Date(timeIntervalSince1970: 1_000)
    let history = ClipboardHistory(persistence: persistence, now: { now })

    history.record("first")
    now.addTimeInterval(1)
    history.record("second")
    now.addTimeInterval(1)
    history.record("first")

    #expect(history.entries.map(\.text) == ["first", "second"])
    #expect(persistence.entries == history.entries)
  }

  @Test("Clipboard history: ignores empty and oversized text")
  func testIgnoresInvalidText() {
    let history = ClipboardHistory(persistence: ClipboardHistoryPersistenceStub())

    history.record(" \n ")
    history.record(String(repeating: "a", count: ClipboardHistory.maximumEntryBytes + 1))

    #expect(history.entries.isEmpty)
  }

  @Test("Clipboard history: removes expired entries when loading")
  func testPrunesExpiredEntries() {
    let now = Date(timeIntervalSince1970: 1_000_000)
    let persistence = ClipboardHistoryPersistenceStub(entries: [
      ClipboardEntry(text: "recent", capturedAt: now.addingTimeInterval(-60)),
      ClipboardEntry(
        text: "expired",
        capturedAt: now.addingTimeInterval(-ClipboardHistory.retentionInterval - 1)
      ),
    ])

    let history = ClipboardHistory(persistence: persistence, now: { now })

    #expect(history.entries.map(\.text) == ["recent"])
  }

  @Test("Clipboard history: encrypted store does not write plaintext")
  func testEncryptedPersistenceRoundTrip() throws {
    let directory = FileManager.default.temporaryDirectory
      .appending(path: UUID().uuidString, directoryHint: .isDirectory)
    let fileURL = directory.appending(path: "history.data")
    let key = SymmetricKey(size: .bits256)
    let store = EncryptedClipboardHistoryStore(fileURL: fileURL, keyProvider: { key })
    let entries = [ClipboardEntry(text: "private clipboard value")]

    try store.save(entries)
    let storedData = try Data(contentsOf: fileURL)

    #expect(!String(decoding: storedData, as: UTF8.self).contains("private clipboard value"))
    #expect(try store.load() == entries)
    try? FileManager.default.removeItem(at: directory)
  }

  @Test("Clipboard monitor: captures external text and suppresses its own writes")
  func testMonitorCaptureAndSelfWriteSuppression() {
    let pasteboard = NSPasteboard.withUniqueName()
    var captured = [String]()
    let monitor = ClipboardMonitor(pasteboard: pasteboard) { captured.append($0) }

    monitor.write("Conjuror value")
    monitor.captureIfChanged()
    #expect(captured.isEmpty)

    pasteboard.clearContents()
    pasteboard.setString("External value", forType: .string)
    monitor.captureIfChanged()
    #expect(captured == ["External value"])
    pasteboard.releaseGlobally()
  }

  @Test("Clipboard monitor: ignores concealed text")
  func testMonitorIgnoresConcealedText() {
    let pasteboard = NSPasteboard.withUniqueName()
    var captured = [String]()
    let monitor = ClipboardMonitor(pasteboard: pasteboard) { captured.append($0) }

    pasteboard.clearContents()
    pasteboard.setString("secret", forType: .string)
    pasteboard.addTypes(
      [NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType")],
      owner: nil
    )
    monitor.captureIfChanged()

    #expect(captured.isEmpty)
    pasteboard.releaseGlobally()
  }
}

final class ClipboardHistoryPersistenceStub: ClipboardHistoryPersisting {
  var entries: [ClipboardEntry]

  init(entries: [ClipboardEntry] = []) {
    self.entries = entries
  }

  func load() throws -> [ClipboardEntry] {
    entries
  }

  func save(_ entries: [ClipboardEntry]) throws {
    self.entries = entries
  }
}
