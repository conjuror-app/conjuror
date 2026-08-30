import Foundation

@MainActor
final class ClipboardHistory: ObservableObject {
  nonisolated static let maximumEntryBytes = 100 * 1_024
  nonisolated static let maximumEntryCount = 500
  nonisolated static let retentionInterval: TimeInterval = 7 * 24 * 60 * 60

  @Published private(set) var entries = [ClipboardEntry]()
  @Published private(set) var persistenceErrorMessage: String?

  private let persistence: ClipboardHistoryPersisting
  private let now: () -> Date

  init(
    persistence: ClipboardHistoryPersisting = EncryptedClipboardHistoryStore(),
    now: @escaping () -> Date = Date.init
  ) {
    self.persistence = persistence
    self.now = now
    do {
      entries = pruned(try persistence.load())
    } catch {
      entries = []
      persistenceErrorMessage = "Couldn’t load clipboard history."
    }
  }

  func record(_ text: String) {
    guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
      text.lengthOfBytes(using: .utf8) <= Self.maximumEntryBytes
    else { return }

    entries.removeAll { $0.text == text }
    entries.insert(ClipboardEntry(text: text, capturedAt: now()), at: 0)
    entries = pruned(entries)
    persist()
  }

  func delete(_ entry: ClipboardEntry) {
    entries.removeAll { $0.id == entry.id }
    persist()
  }

  func clear() {
    entries.removeAll()
    persist()
  }

  private func pruned(_ entries: [ClipboardEntry]) -> [ClipboardEntry] {
    let cutoff = now().addingTimeInterval(-Self.retentionInterval)
    return
      entries
      .filter { $0.capturedAt >= cutoff }
      .sorted { $0.capturedAt > $1.capturedAt }
      .prefix(Self.maximumEntryCount)
      .map { $0 }
  }

  private func persist() {
    do {
      try persistence.save(entries)
      persistenceErrorMessage = nil
    } catch {
      persistenceErrorMessage = "Couldn’t save clipboard history."
    }
  }
}
