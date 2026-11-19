import AppKit
import SwiftUI

struct FileResultRow: View {
  let result: FileSearchResult
  let layout: LauncherLayout
  let isSelected: Bool
  let onHover: () -> Void
  let onOpen: () -> Void

  var body: some View {
    HStack(spacing: layout.appearance.usesTypography ? layout.resultIconSpacing : 10) {
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
      LauncherResultHint(
        id: .file(result.id),
        isSelected: isSelected,
        layout: layout,
        actionTitle: "Open"
      )
    }
    .padding(.horizontal, 8)
    .frame(height: layout.resultRowHeight)
    .modifier(
      LauncherResultHighlight(
        layout: layout,
        isSelected: isSelected,
        cornerRadius: 7,
        accentOpacity: 0.18
      )
    )
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

  @ViewBuilder
  private var filename: some View {
    if layout.appearance.usesTypography {
      LauncherResultTitle(name: result.displayName, layout: layout)
    } else {
      Text(result.displayName)
        .lineLimit(1)
    }
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
