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

struct CommandBarBadge: View {
  let text: String
  var design: Font.Design = .monospaced

  var body: some View {
    Text(text)
      .font(.system(size: 10.5, weight: .medium, design: design))
      .foregroundStyle(.secondary)
      .lineLimit(1)
      .padding(.horizontal, 6)
      .padding(.vertical, 2)
      .background(
        .primary.opacity(0.07),
        in: RoundedRectangle(cornerRadius: 5, style: .continuous)
      )
      .overlay {
        RoundedRectangle(cornerRadius: 5, style: .continuous)
          .strokeBorder(.primary.opacity(0.08), lineWidth: 0.5)
      }
  }
}

struct CommandBarIconBadge: View {
  let systemImage: String
  let size: CGFloat
  var fontSize: CGFloat = 12
  var foreground: Color = .primary.opacity(0.85)
  var background: Color = .primary.opacity(0.08)
  var border: Color = .primary.opacity(0.08)

  var body: some View {
    Image(systemName: systemImage)
      .font(.system(size: fontSize, weight: .medium))
      .foregroundStyle(foreground)
      .frame(width: size, height: size)
      .background(
        background,
        in: RoundedRectangle(cornerRadius: 6, style: .continuous)
      )
      .overlay {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
          .strokeBorder(border, lineWidth: 0.5)
      }
  }
}
