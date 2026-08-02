import SwiftUI

struct LauncherResultRow: View {
    let application: InstalledApplication
    let isSelected: Bool
    let onHover: () -> Void
    let onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: 11) {
                Image(nsImage: application.icon)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 28, height: 28)

                Text(application.displayName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Spacer()

                if isSelected {
                    Text("↵")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 11)
            .frame(height: 44)
            .contentShape(Rectangle())
            .background {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? Color.primary.opacity(0.07) : .clear)
            }
        }
        .buttonStyle(.plain)
        .onHover { isHovering in
            if isHovering {
                onHover()
            }
        }
        .help("Open \(application.displayName)")
    }
}
