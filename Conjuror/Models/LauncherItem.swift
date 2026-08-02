import Foundation

struct LauncherItem: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let systemImage: String
    let shortcut: String?

    var searchableText: String {
        "\(title) \(subtitle)"
    }

    static let suggestions = [
        LauncherItem(
            id: "applications",
            title: "Open Applications",
            subtitle: "Browse and launch installed apps",
            systemImage: "square.grid.2x2",
            shortcut: "⌘ A"
        ),
        LauncherItem(
            id: "files",
            title: "Search Files",
            subtitle: "Find documents, folders, and downloads",
            systemImage: "doc.text.magnifyingglass",
            shortcut: "⌘ F"
        ),
        LauncherItem(
            id: "clipboard",
            title: "Clipboard History",
            subtitle: "Return to something you copied",
            systemImage: "doc.on.clipboard",
            shortcut: "⇧ ⌘ V"
        ),
        LauncherItem(
            id: "note",
            title: "Quick Note",
            subtitle: "Capture a thought without breaking focus",
            systemImage: "square.and.pencil",
            shortcut: "⌘ N"
        ),
        LauncherItem(
            id: "shell",
            title: "Run Shell Command",
            subtitle: "Execute a command from anywhere",
            systemImage: "terminal",
            shortcut: nil
        ),
        LauncherItem(
            id: "settings",
            title: "System Settings",
            subtitle: "Open macOS settings",
            systemImage: "gearshape",
            shortcut: nil
        ),
    ]
}
