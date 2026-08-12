import Foundation

struct ShortcutRunner: ShortcutRunning {
  func run(_ shortcut: AppleShortcut) async throws {
    let identifier = shortcut.id
    let runTask = Task.detached(priority: .userInitiated) {
      try ShortcutsEventsBridge.runShortcut(identifier: identifier)
      try Task.checkCancellation()
    }
    try await withTaskCancellationHandler {
      try await runTask.value
    } onCancel: {
      runTask.cancel()
    }
  }
}

protocol ShortcutRunning {
  @MainActor
  func run(_ shortcut: AppleShortcut) async throws
}
