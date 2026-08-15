import SwiftUI

struct ApplicationResultRow: View {
  let application: InstalledApplication
  let isSelected: Bool
  let onHover: () -> Void
  let onOpen: () -> Void

  var body: some View {
    SelectableResultRow(
      isSelected: isSelected,
      accessibilityLabel: application.displayName,
      accessibilityHint: "Opens the application",
      help: "Open \(application.displayName)",
      action: onOpen,
      onHover: onHover
    ) {
      Image(nsImage: application.icon)
        .resizable()
        .interpolation(.high)
        .frame(width: 26, height: 26)

      Text(application.displayName)
        .font(.system(size: 14, weight: .medium))
        .foregroundStyle(.primary)
        .lineLimit(1)

      Spacer()
    }
  }
}
