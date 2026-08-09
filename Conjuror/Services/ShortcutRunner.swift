import Foundation

struct ShortcutRunner: ShortcutRunning {
    func run(_ shortcut: AppleShortcut) async throws {
        let identifier = shortcut.id
        try await Task.detached(priority: .userInitiated) {
            try ShortcutsEventsBridge.runShortcut(identifier: identifier)
        }.value
    }
}

protocol ShortcutRunning {
    @MainActor
    func run(_ shortcut: AppleShortcut) async throws
}
