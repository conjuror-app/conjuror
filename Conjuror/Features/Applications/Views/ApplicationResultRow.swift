import SwiftUI

struct ApplicationResultRow: View {
  let application: InstalledApplication
  let isSelected: Bool
  let onHover: () -> Void
  let onOpen: () -> Void

  var body: some View {
    Button(action: onOpen) {
      HStack(spacing: 8) {
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
      .padding(.horizontal, 7)
      .frame(height: 40)
      .contentShape(Rectangle())
      .background {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
          .fill(isSelected ? Color.primary.opacity(0.07) : .clear)
      }
    }
    .buttonStyle(.plain)
    .accessibilityLabel(application.displayName)
    .accessibilityHint("Opens the application")
    .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    .onHover { isHovering in
      if isHovering {
        onHover()
      }
    }
    .help("Open \(application.displayName)")
  }
}
