import SwiftUI

struct CalculatorResultRow: View {
  let result: CalculatorResult
  let isSelected: Bool
  let onHover: () -> Void
  let onCopy: () -> Void

  var body: some View {
    SelectableResultRow(
      isSelected: isSelected,
      accessibilityLabel: accessibilityLabel,
      accessibilityHint: "Copies the result",
      help: "Copy " + result.copyText,
      action: onCopy,
      onHover: onHover
    ) {
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
