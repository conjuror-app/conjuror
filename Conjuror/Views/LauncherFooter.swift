import SwiftUI

struct LauncherFooter: View {
    let onQuit: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Label("Conjuror", systemImage: "sparkles")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)

            Spacer()

            ShortcutHint(keys: "↑ ↓", label: "Navigate")
            ShortcutHint(keys: "esc", label: "Clear")

            Button(action: onQuit) {
                ShortcutHint(keys: "⌘ Q", label: "Quit")
            }
            .buttonStyle(.plain)
            .keyboardShortcut("q", modifiers: .command)
            .help("Quit Conjuror")
        }
        .padding(.horizontal, 22)
        .frame(height: 42)
    }
}

private struct ShortcutHint: View {
    let keys: String
    let label: String

    var body: some View {
        HStack(spacing: 5) {
            Text(keys)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 5))

            Text(label)
                .font(.caption)
        }
        .foregroundStyle(.tertiary)
    }
}
