import SwiftUI

struct SelectableResultRow<Content: View>: View {
  let isSelected: Bool
  let layout: LauncherLayout
  let accessibilityLabel: String
  let accessibilityHint: String
  let help: String
  let action: () -> Void
  let onHover: () -> Void
  @ViewBuilder let content: () -> Content

  var body: some View {
    Button(action: action) {
      HStack(spacing: layout.isCommandBar ? 10 : 8) {
        content()
      }
      .padding(.horizontal, layout.isCommandBar ? 10 : 7)
      .frame(height: layout.resultRowHeight)
      .contentShape(Rectangle())
      .background {
        let shape = RoundedRectangle(cornerRadius: 8, style: .continuous)
        if layout.isCommandBar {
          shape
            .fill(isSelected ? Color.primary.opacity(0.10) : .clear)
            .overlay {
              if isSelected {
                shape.strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
              }
            }
        } else {
          shape
            .fill(isSelected ? Color.accentColor.opacity(0.14) : .clear)
        }
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
