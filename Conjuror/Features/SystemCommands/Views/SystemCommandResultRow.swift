import SwiftUI

struct SystemCommandResultRow: View {
  let command: SystemCommand
  let layout: LauncherLayout
  let isSelected: Bool
  let isArmed: Bool
  let onHover: () -> Void
  let onRun: () -> Void

  var body: some View {
    SelectableResultRow(
      isSelected: isSelected,
      layout: layout,
      accessibilityLabel: isArmed
        ? "\(command.title), \(command.confirmationTitle)" : command.title,
      accessibilityHint: isArmed
        ? "Press Return again to confirm"
        : command.requiresConfirmation
          ? "Asks for confirmation before running" : "Runs the command",
      help: command.title,
      action: onRun,
      onHover: onHover
    ) {
      Image(systemName: command.systemImage)
        .font(.system(size: layout.shortcutSymbolSize, weight: .medium))
        .foregroundStyle(isArmed ? .red : .secondary)
        .frame(width: layout.resultIconSize, height: layout.resultIconSize)

      VStack(alignment: .leading, spacing: 1) {
        Text(command.title)
          .font(.system(size: layout.resultFontSize, weight: .medium))
          .foregroundStyle(.primary)
          .lineLimit(1)

        if layout.appearance == .standard {
          caption
            .font(.caption)
        }
      }

      Spacer()

      if layout.appearance == .minimal {
        caption
          .font(.caption2)
      }
    }
  }

  private var caption: some View {
    Text(isArmed ? "\(command.confirmationTitle) Press Return again" : "System")
      .foregroundStyle(isArmed ? AnyShapeStyle(.red) : AnyShapeStyle(.secondary))
      .lineLimit(1)
  }
}
