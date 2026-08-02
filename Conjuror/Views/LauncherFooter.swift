import SwiftUI

struct LauncherFooter: View {
    let onQuit: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            ShortcutHint(keys: "↑↓", label: "navigate")
            ShortcutHint(keys: "↵", label: "open")
            ShortcutHint(keys: "esc", label: "close")

            Spacer()

            Button(action: onQuit) {
                ShortcutHint(keys: "⌘Q", label: "quit")
            }
            .buttonStyle(.plain)
            .keyboardShortcut("q", modifiers: .command)
            .help("Quit Conjuror")
        }
        .padding(.horizontal, 16)
        .frame(height: 32)
    }
}

private struct ShortcutHint: View {
    let keys: String
    let label: String

    var body: some View {
        Text("\(keys)  \(label)")
            .font(.system(size: 11, weight: .regular))
            .foregroundStyle(.tertiary)
    }
}
