import Foundation

struct ShortcutCatalog: ShortcutCatalogLoading {
  func load() async throws -> [AppleShortcut] {
    let loadTask = Task.detached(priority: .userInitiated) {
      let shortcuts = try ShortcutsEventsBridge.loadShortcuts()
      try Task.checkCancellation()
      return shortcuts.filter { !$0.acceptsInput }
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
