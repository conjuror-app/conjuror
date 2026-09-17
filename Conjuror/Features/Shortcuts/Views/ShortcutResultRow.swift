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
    } else {
      Image(systemName: "square.stack.3d.up.fill")
        .font(.system(size: layout.shortcutSymbolSize, weight: .medium))
        .foregroundStyle(.purple)
        .frame(width: layout.resultIconSize, height: layout.resultIconSize)
    }
  }
}
