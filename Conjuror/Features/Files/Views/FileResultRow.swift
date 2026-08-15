import AppKit
import SwiftUI

struct FileResultRow: View {
  let result: FileSearchResult
  let isSelected: Bool
  let onHover: () -> Void
  let onOpen: () -> Void

  var body: some View {
    HStack(spacing: 10) {
      Image(nsImage: icon)
        .resizable()
        .scaledToFit()
        .frame(width: 30, height: 30)

      VStack(alignment: .leading, spacing: 1) {
        Text(result.displayName)
          .lineLimit(1)
        Text(result.parentPath)
          .font(.caption)
          .foregroundStyle(.secondary)
          .lineLimit(1)
          .truncationMode(.middle)
      }

      Spacer(minLength: 4)
    }
    .padding(.horizontal, 8)
    .frame(height: 40)
    .background(isSelected ? Color.accentColor.opacity(0.18) : .clear)
    .clipShape(RoundedRectangle(cornerRadius: 7))
    .contentShape(Rectangle())
    .onHover { hovering in
      if hovering { onHover() }
    }
    .onTapGesture(count: 2, perform: onOpen)
  }

  private var icon: NSImage {
    let icon = NSWorkspace.shared.icon(forFile: result.url.path)
    icon.size = NSSize(width: 32, height: 32)
    return icon
  }
}
