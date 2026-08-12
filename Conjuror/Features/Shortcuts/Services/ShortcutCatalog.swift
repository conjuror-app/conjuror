import Foundation

struct ShortcutCatalog: ShortcutCatalogLoading {
  static func excludingInputShortcuts(
    _ shortcuts: [AppleShortcut]
  ) -> [AppleShortcut] {
    shortcuts.filter { !$0.acceptsInput }
  }

  func load() async throws -> [AppleShortcut] {
    let loadTask = Task.detached(priority: .userInitiated) {
      let shortcuts = try ShortcutsEventsBridge.loadShortcuts()
      try Task.checkCancellation()
      return Self.excludingInputShortcuts(shortcuts)
    }
    return try await withTaskCancellationHandler {
      try await loadTask.value
    } onCancel: {
      loadTask.cancel()
    }
  }
}

protocol ShortcutCatalogLoading {
  @MainActor
  func load() async throws -> [AppleShortcut]
}
