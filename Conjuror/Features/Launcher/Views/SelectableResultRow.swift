import SwiftUI

struct SelectableResultRow<Content: View>: View {
  let isSelected: Bool
  let accessibilityLabel: String
  let accessibilityHint: String
  let help: String
  let action: () -> Void
  let onHover: () -> Void
  @ViewBuilder let content: () -> Content

  var body: some View {
    Button(action: action) {
      HStack(spacing: 8) {
        content()
      }
      .padding(.horizontal, 7)
      .frame(height: 40)
      .contentShape(Rectangle())
      .background {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
          .fill(isSelected ? Color.accentColor.opacity(0.14) : .clear)
      }
    }
    .buttonStyle(.plain)
    .accessibilityLabel(accessibilityLabel)
    .accessibilityHint(accessibilityHint)
    .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    .onHover { isHovering in
      if isHovering { onHover() }
    }
    .help(help)
  }
}
