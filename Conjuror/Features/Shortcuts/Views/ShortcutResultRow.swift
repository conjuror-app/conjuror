import SwiftUI

struct ShortcutResultRow: View {
  let shortcut: AppleShortcut
  let layout: LauncherLayout
  let isSelected: Bool
  let onHover: () -> Void
  let onRun: () -> Void

  var body: some View {
    SelectableResultRow(
      isSelected: isSelected,
      layout: layout,
      accessibilityLabel: shortcut.name,
      accessibilityHint: "Runs the shortcut",
      help: "Run \(shortcut.name)",
      action: onRun,
      onHover: onHover
    ) {
      shortcutIcon

      Text(shortcut.name)
        .font(.system(size: layout.resultFontSize, weight: .medium))
        .foregroundStyle(.primary)
        .lineLimit(1)

      Spacer()

      if layout.isCommandBar {
        Text("Shortcut")
          .font(.system(size: 12))
          .foregroundStyle(.tertiary)
          .lineLimit(1)
      }
    }
  }

  @ViewBuilder private var shortcutIcon: some View {
    if let iconData = shortcut.iconData,
      let icon = NSImage(data: iconData)
    {
      Image(nsImage: icon)
        .resizable()
        .interpolation(.high)
        .frame(width: layout.resultIconSize, height: layout.resultIconSize)
    } else if layout.isCommandBar {
      Image(systemName: "square.stack.3d.up.fill")
        .font(.system(size: 12, weight: .medium))
        .foregroundStyle(.purple)
        .frame(width: layout.resultIconSize, height: layout.resultIconSize)
        .background(Color.purple.opacity(0.15), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay {
          RoundedRectangle(cornerRadius: 6, style: .continuous)
            .strokeBorder(Color.purple.opacity(0.25), lineWidth: 0.5)
        }
    } else {
      Image(systemName: "square.stack.3d.up.fill")
        .font(.system(size: layout.shortcutSymbolSize, weight: .medium))
        .foregroundStyle(.purple)
        .frame(width: layout.resultIconSize, height: layout.resultIconSize)
    }
  }
}
