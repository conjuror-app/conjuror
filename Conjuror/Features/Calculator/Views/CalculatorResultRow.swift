import SwiftUI

struct CalculatorResultRow: View {
  let result: CalculatorResult
  let layout: LauncherLayout
  let isSelected: Bool
  let onHover: () -> Void
  let onCopy: () -> Void

  var body: some View {
    if layout.isCommandBar {
      commandBarCard
    } else {
      standardRow
    }
  }

  private var commandBarCard: some View {
    Button(action: onCopy) {
      HStack(spacing: 12) {
        VStack(spacing: 6) {
          Text(result.sourceDisplay ?? result.expression)
            .font(.system(size: 19, weight: .medium, design: .rounded))
            .foregroundStyle(.primary.opacity(0.82))
            .lineLimit(1)
            .minimumScaleFactor(0.75)

          if let sourceBadge = result.sourceBadge {
            badge(sourceBadge)
          }
        }
        .frame(maxWidth: .infinity)

        Image(systemName: "arrow.right")
          .font(.system(size: 13, weight: .medium))
          .foregroundStyle(.tertiary)

        VStack(spacing: 6) {
          Text(result.display)
            .font(.system(size: 21, weight: .semibold, design: .rounded))
            .foregroundStyle(.primary)
            .lineLimit(1)
            .minimumScaleFactor(0.75)

          if let targetBadge = result.targetBadge {
            badge(targetBadge)
          }
        }
        .frame(maxWidth: .infinity)
      }
      .padding(.horizontal, 16)
      .frame(height: LauncherLayout.calculatorCardHeight)
      .contentShape(Rectangle())
      .background {
        let shape = RoundedRectangle(cornerRadius: 8, style: .continuous)
        shape
          .fill(Color.primary.opacity(isSelected ? 0.10 : 0.05))
          .overlay {
            shape.strokeBorder(
              Color.primary.opacity(isSelected ? 0.16 : 0.08),
              lineWidth: 0.75
            )
          }
      }
    }
    .buttonStyle(.plain)
    .accessibilityLabel(accessibilityLabel)
    .accessibilityHint("Copies the result")
    .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    .onHover { isHovering in
      if isHovering { onHover() }
    }
    .help("Copy " + result.copyText)
  }

  private var standardRow: some View {
    SelectableResultRow(
      isSelected: isSelected,
      layout: layout,
      accessibilityLabel: accessibilityLabel,
      accessibilityHint: "Copies the result",
      help: "Copy " + result.copyText,
      action: onCopy,
      onHover: onHover
    ) {
      Image(systemName: "equal.circle.fill")
        .font(.system(size: layout.calculatorSymbolSize))
        .foregroundStyle(.blue)
        .frame(width: layout.resultIconSize, height: layout.resultIconSize)

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
