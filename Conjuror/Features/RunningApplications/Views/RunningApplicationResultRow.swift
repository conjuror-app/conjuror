import SwiftUI

struct RunningApplicationResultRow: View {
  let application: RunningApplication
  let layout: LauncherLayout
  let isSelected: Bool
  let onHover: () -> Void
  let onSwitch: () -> Void

  var body: some View {
    SelectableResultRow(
      id: .runningApplication(application.id),
      isSelected: isSelected,
      layout: layout,
      actionTitle: "Switch",
      accessibilityLabel: application.isHidden
        ? "\(application.displayName), hidden" : application.displayName,
      accessibilityHint: "Switches to the application",
      help: "Switch to \(application.displayName)",
      action: onSwitch,
      onHover: onHover
    ) {
      Image(nsImage: application.icon)
        .resizable()
        .interpolation(.high)
        .frame(width: layout.resultIconSize, height: layout.resultIconSize)
        .opacity(application.isHidden ? 0.5 : 1)

      LauncherResultTitle(
        name: application.displayName,
        layout: layout,
        secondaryText: application.bundleIdentifier ?? ""
      )

      Spacer()

      if application.isHidden {
        Text("Hidden")
          .font(layout.appearance == .standard ? .caption : .caption2)
          .foregroundStyle(.secondary)
          .lineLimit(1)
      }
    }
  }
}
