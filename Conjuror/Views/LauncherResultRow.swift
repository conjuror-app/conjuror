import SwiftUI

struct LauncherResultRow: View {
    let item: LauncherItem
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 13) {
                Image(systemName: item.systemImage)
                    .font(.system(size: 16, weight: .medium))
                    .frame(width: 36, height: 36)
                    .foregroundStyle(isSelected ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
                    .background {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(
                                isSelected
                                    ? AnyShapeStyle(
                                        .linearGradient(
                                            colors: [.cyan, .purple],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    : AnyShapeStyle(.quaternary)
                            )
                    }

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.primary)

                    Text(item.subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if let shortcut = item.shortcut {
                    Text(shortcut)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
                }

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(isSelected ? .secondary : .quaternary)
            }
            .padding(.horizontal, 12)
            .frame(height: 52)
            .contentShape(Rectangle())
            .background {
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? AnyShapeStyle(.thinMaterial) : AnyShapeStyle(.clear))
            }
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(.quaternary, lineWidth: 1)
                }
            }
        }
        .buttonStyle(.plain)
        .onHover { isHovering in
            if isHovering {
                onSelect()
            }
        }
    }
}
