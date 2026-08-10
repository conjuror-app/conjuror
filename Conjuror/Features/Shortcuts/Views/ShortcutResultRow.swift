import SwiftUI

struct ShortcutResultRow: View {
  let shortcut: AppleShortcut
  let isSelected: Bool
  let onHover: () -> Void
  let onRun: () -> Void

  var body: some View {
    Button(action: onRun) {
      HStack(spacing: 8) {
        shortcutIcon

        Text(shortcut.name)
          .font(.system(size: 14, weight: .medium))
          .foregroundStyle(.primary)
          .lineLimit(1)

        Spacer()

        if let actionCount = shortcut.actionCount, actionCount > 0 {
          Text("\(actionCount) \(actionCount == 1 ? "action" : "actions")")
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }

        if isSelected {
          Text("↵")
            .font(.system(size: 13, weight: .medium, design: .rounded))
            .foregroundStyle(.tertiary)
            .accessibilityHidden(true)
        }
      }
      .padding(.horizontal, 7)
      .frame(height: 40)
      .contentShape(Rectangle())
      .background {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
          .fill(isSelected ? Color.primary.opacity(0.07) : .clear)
      }
    }
    .buttonStyle(.plain)
    .accessibilityLabel(shortcut.name)
    .accessibilityHint("Runs the shortcut")
    .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    .onHover { isHovering in
      if isHovering {
        onHover()
      }
    }
    .help("Run \(shortcut.name)")
  }

  @ViewBuilder private var shortcutIcon: some View {
    if let iconData = shortcut.iconData,
      let icon = NSImage(data: iconData)
    {
      Image(nsImage: icon)
        .resizable()
        .interpolation(.high)
        .frame(width: 26, height: 26)
    } else {
      Image(systemName: "square.stack.3d.up.fill")
        .font(.system(size: 17, weight: .medium))
        .foregroundStyle(.purple)
        .frame(width: 26, height: 26)
    }
  }
}
