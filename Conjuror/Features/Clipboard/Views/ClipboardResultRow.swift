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
      isSelected: isSelected,
      layout: layout,
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

      Text(item.preview)
        .font(.system(size: layout.resultFontSize, weight: .medium))
        .foregroundStyle(.primary)
        .lineLimit(1)
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
