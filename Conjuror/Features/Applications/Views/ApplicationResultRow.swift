import SwiftUI

struct ApplicationResultRow: View {
  let application: InstalledApplication
  let layout: LauncherLayout
  let isSelected: Bool
  let onHover: () -> Void
  let onOpen: () -> Void

  var body: some View {
    SelectableResultRow(
      isSelected: isSelected,
      layout: layout,
      accessibilityLabel: application.displayName,
      accessibilityHint: application.isSystemSettingsItem
        ? "Opens this section in System Settings"
        : "Opens the application",
      help: "Open \(application.displayName)",
      action: onOpen,
      onHover: onHover
    ) {
      Image(nsImage: application.icon)
        .resizable()
        .interpolation(.high)
        .frame(width: layout.resultIconSize, height: layout.resultIconSize)

      VStack(alignment: .leading, spacing: 1) {
        Text(application.displayName)
          .font(.system(size: layout.resultFontSize, weight: .medium))
          .foregroundStyle(.primary)
          .lineLimit(1)

        if application.isSystemSettingsItem && layout.appearance == .standard {
          Text("System Settings")
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
      }

      Spacer()

      if application.isSystemSettingsItem && layout.appearance == .minimal {
        Text("System Settings")
          .font(.caption2)
          .foregroundStyle(.secondary)
          .lineLimit(1)
      }
    }
  }
}
