import SwiftUI

struct LauncherResultRow: View {
    let application: InstalledApplication
    let isSelected: Bool
    let onHover: () -> Void
    let onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: 13) {
                Image(nsImage: application.icon)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 36, height: 36)

                VStack(alignment: .leading, spacing: 2) {
                    Text(application.displayName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.primary)

                    Text(application.bundleIdentifier ?? application.url.deletingLastPathComponent().path)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                if isSelected {
                    Text("↵ Open")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
                }
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
                onHover()
            }
        }
        .help("Open \(application.displayName)")
    }
}
