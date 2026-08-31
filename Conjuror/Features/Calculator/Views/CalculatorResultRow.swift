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

      Text(result.expression)
        .font(.system(size: 13))
        .foregroundStyle(.secondary)
        .lineLimit(1)

      Spacer(minLength: 12)

      Text(result.display)
        .font(.system(size: 14, weight: .semibold, design: .rounded))
        .foregroundStyle(.primary)
        .lineLimit(1)

    }
  }

  private var accessibilityLabel: String {
    "Calculator result " + result.display
  }
}
