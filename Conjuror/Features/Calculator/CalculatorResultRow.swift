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

                Text(result.expression)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Spacer(minLength: 12)

                Text(result.display)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                if isSelected {
                    Text("↵")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.tertiary)
                        .accessibilityHidden(true)
                }
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
        .accessibilityLabel("Calculator result " + result.display)
        .accessibilityHint("Copies the result")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
        .onHover { isHovering in
            if isHovering {
                onHover()
            }
        }
        .help("Copy " + result.copyText)
    }
}
