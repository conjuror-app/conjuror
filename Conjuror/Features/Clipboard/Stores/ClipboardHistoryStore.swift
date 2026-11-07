import Combine
import Foundation

/// Copied text, newest first, saved to a file only the user can read.
@MainActor
final class ClipboardHistoryStore: ObservableObject {
  static let maximumItemCount = 1_000

  static func defaultURL() -> URL {
    FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
      .appendingPathComponent(Bundle.main.bundleIdentifier ?? "Conjuror", isDirectory: true)
      .appendingPathComponent("clipboard-history.json")
  }

  @Published private(set) var items: [ClipboardItem]

  private(set) var retention = ClipboardHistoryRetention.default

  /// `nil` keeps the history in memory only.
  private let fileURL: URL?
  private let now: () -> Date

  init(fileURL: URL?, now: @escaping () -> Date = Date.init) {
    self.fileURL = fileURL
    self.now = now
    items =
      fileURL
      .flatMap { try? Data(contentsOf: $0) }
      .flatMap { try? JSONDecoder().decode([ClipboardItem].self, from: $0) } ?? []
  }

  /// Adds copied text. Copying text that's already in the history moves it to the top.
  func record(_ text: String, source: ClipboardSource?) {
    let date = now()
    var item =
      items.first { $0.text == text }
      ?? ClipboardItem(
        id: UUID(),
        text: text,
        source: source,
        firstCopiedAt: date,
        lastCopiedAt: date
      )
    item.lastCopiedAt = date

    var updatedItems = items.filter { $0.id != item.id }
    updatedItems.insert(item, at: 0)
    replaceItems(with: updatedItems)
  }

  func remove(id: ClipboardItem.ID) {
    replaceItems(with: items.filter { $0.id != id })
  }

  func removeAll() {
    items = []

    guard let fileURL, FileManager.default.fileExists(atPath: fileURL.path) else { return }

    try? FileManager.default.removeItem(at: fileURL)
  }

  func setRetention(_ retention: ClipboardHistoryRetention) {
    self.retention = retention
    replaceItems(with: items)
  }

  /// Drops items past the retention period and the item limit, then saves the rest.
  private func replaceItems(with newItems: [ClipboardItem]) {
    let cutoff = retention.cutoff(before: now())
    let keptItems = Array(
      newItems
        .filter { item in cutoff.map { item.lastCopiedAt >= $0 } ?? true }
        .prefix(Self.maximumItemCount)
    )

    guard keptItems != items else { return }

    items = keptItems
    save()
  }

  private func save() {
    guard let fileURL, let data = try? JSONEncoder().encode(items) else { return }

    let fileManager = FileManager.default
    try? fileManager.createDirectory(
      at: fileURL.deletingLastPathComponent(),
      withIntermediateDirectories: true,
      attributes: [.posixPermissions: 0o700]
    )

    guard (try? data.write(to: fileURL, options: .atomic)) != nil else { return }

    try? fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: fileURL.path)
  }
}
