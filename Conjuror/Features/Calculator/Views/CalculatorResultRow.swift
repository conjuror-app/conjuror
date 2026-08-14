import SwiftUI

struct CalculatorResultRow: View {
  let result: CalculatorResult
  let isSelected: Bool
  let onHover: () -> Void
  let onCopy: () -> Void

  var body: some View {
    Button(action: onCopy) {
      HStack(spacing: 8) {
        Image(systemName: "equal.circle.fill")
          .font(.system(size: 22))
          .foregroundStyle(.blue)
          .frame(width: 26, height: 26)

        Text(result.sourceDisplay ?? result.expression)
          .font(.system(size: 13))
          .foregroundStyle(.secondary)
          .lineLimit(1)

        if let sourceBadge = result.sourceBadge {
          badge(sourceBadge)
        }

        Spacer(minLength: 12)

        Text(result.display)
          .font(.system(size: 14, weight: .semibold, design: .rounded))
          .foregroundStyle(.primary)
          .lineLimit(1)

        if let targetBadge = result.targetBadge {
          badge(targetBadge)
        }
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
    .accessibilityHint("Copies the result")
    .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    .onHover { isHovering in
      if isHovering {
        onHover()
      }
    }
    .help("Copy " + result.copyText)
  }

  private var accessibilityLabel: String {
    ["Calculator result", result.display, result.targetBadge]
      .compactMap { $0 }
      .joined(separator: " ")
  }

  private func badge(_ text: String) -> some View {
    Text(text)
      .font(.system(size: 10, weight: .medium, design: .rounded))
      .foregroundStyle(.secondary)
      .padding(.horizontal, 5)
      .frame(height: 18)
      .background(.primary.opacity(0.06), in: Capsule())
  }
}
