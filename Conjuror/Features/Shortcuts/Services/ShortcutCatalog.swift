import Foundation

struct ShortcutCatalog: ShortcutCatalogLoading {
  static func excludingInputShortcuts(
    _ shortcuts: [AppleShortcut]
  ) -> [AppleShortcut] {
    shortcuts.filter { !$0.acceptsInput }
  }

  func load() async throws -> [AppleShortcut] {
    try await Task.detached(priority: .userInitiated) {
      Self.excludingInputShortcuts(
        try ShortcutsEventsBridge.loadShortcuts()
      )
    }.value
  }
}

protocol ShortcutCatalogLoading {
  @MainActor
  func load() async throws -> [AppleShortcut]
}
