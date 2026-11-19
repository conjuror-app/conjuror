import SwiftUI

struct ClipboardResultRow: View {
  let item: ClipboardItem
  let layout: LauncherLayout
  let isSelected: Bool
  let actionTitle: String
  let onHover: () -> Void
  let onSelect: () -> Void

  var body: some View {
    SelectableResultRow(
      id: .clipboardItem(item.id),
      isSelected: isSelected,
      layout: layout,
      actionTitle: actionTitle,
      accessibilityLabel: item.preview,
      accessibilityHint: "\(actionTitle)s the copied text",
      help: actionTitle,
      action: onSelect,
      onHover: onHover
    ) {
      Image(systemName: "doc.on.clipboard")
        .font(.system(size: layout.shortcutSymbolSize, weight: .medium))
        .foregroundStyle(.secondary)
        .frame(width: layout.resultIconSize, height: layout.resultIconSize)

      LauncherResultTitle(name: item.preview, layout: layout, highlightsName: false)
        .truncationMode(.tail)

      Spacer(minLength: 12)

      Text(detail)
        .font(.caption)
        .foregroundStyle(.secondary)
        .lineLimit(1)
        .layoutPriority(1)
    }
  }

  private var detail: String {
    let age = item.lastCopiedAt.formatted(.relative(presentation: .named, unitsStyle: .abbreviated))

    guard let name = item.source?.name else { return age }

    return "\(name) · \(age)"
  }
}
