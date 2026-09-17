import AppKit
import SwiftUI

struct FileResultRow: View {
  let result: FileSearchResult
  let layout: LauncherLayout
  let isSelected: Bool
  let onHover: () -> Void
  let onOpen: () -> Void

  var body: some View {
    HStack(spacing: 10) {
      Image(nsImage: icon)
        .resizable()
        .scaledToFit()
        .frame(width: layout.fileIconSize, height: layout.fileIconSize)

      if layout.appearance == .minimal {
        filename
        Spacer(minLength: 4)
        parentPath
          .frame(maxWidth: LauncherLayout.width / 2, alignment: .trailing)
      } else {
        VStack(alignment: .leading, spacing: 1) {
          filename
          parentPath
        }
        Spacer(minLength: 4)
      }
    }
    .padding(.horizontal, 8)
    .frame(height: layout.resultRowHeight)
    .background(isSelected ? Color.accentColor.opacity(0.18) : .clear)
    .clipShape(RoundedRectangle(cornerRadius: 7))
    .contentShape(Rectangle())
    .onHover { hovering in
      if hovering { onHover() }
    }
    .onTapGesture(count: 2, perform: onOpen)
    .help(result.url.path)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(result.displayName)
    .accessibilityValue(result.url.path)
    .accessibilityHint("Opens the file or folder")
    .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    .accessibilityAction { onOpen() }
  }

  private var filename: some View {
    Text(result.displayName)
      .lineLimit(1)
  }

  private var parentPath: some View {
    Text(result.parentPath)
      .font(.caption)
      .foregroundStyle(.secondary)
      .lineLimit(1)
      .truncationMode(.middle)
  }

  private var icon: NSImage {
    let icon = NSWorkspace.shared.icon(forFile: result.url.path)
    icon.size = NSSize(width: 32, height: 32)
    return icon
  }
}
