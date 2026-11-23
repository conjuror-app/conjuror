import SwiftUI

struct ApplicationResultRow: View {
  let application: InstalledApplication
  let alias: String?
  let layout: LauncherLayout
  let isSelected: Bool
  let onHover: () -> Void
  let onOpen: () -> Void

  var body: some View {
    SelectableResultRow(
      isSelected: isSelected,
      layout: layout,
      accessibilityLabel: alias.map { "\(application.displayName), alias \($0)" }
        ?? application.displayName,
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

      if layout.isCommandBar {
        Text(application.displayName)
          .font(.system(size: layout.resultFontSize, weight: .medium))
          .foregroundStyle(.primary)
          .lineLimit(1)

        Spacer()

        if let alias {
          Text(alias)
            .font(.system(size: 10.5, weight: .medium, design: .monospaced))
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(.primary.opacity(0.07), in: RoundedRectangle(cornerRadius: 5, style: .continuous))
            .overlay {
              RoundedRectangle(cornerRadius: 5, style: .continuous)
                .strokeBorder(.primary.opacity(0.08), lineWidth: 0.5)
            }
            .accessibilityHidden(true)
        }

        Text(application.isSystemSettingsItem ? "System Settings" : "Application")
          .font(.system(size: 12))
          .foregroundStyle(.tertiary)
          .lineLimit(1)
      } else {
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

        if let alias {
          Text(alias)
            .font(.caption.monospaced())
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .padding(.horizontal, 6)
            .padding(.vertical, 1)
            .background(.quaternary, in: Capsule())
            .accessibilityHidden(true)
        }
      }
    }
  }
}
