import SwiftUI

struct ClipboardResultRow: View {
  let entry: ClipboardEntry
  let layout: LauncherLayout
  let isSelected: Bool
  let onHover: () -> Void
  let onCopy: () -> Void

  var body: some View {
    SelectableResultRow(
      isSelected: isSelected,
      layout: layout,
      accessibilityLabel: entry.text,
      accessibilityHint: "Copies this entry to the clipboard",
      help: entry.text,
      action: onCopy,
      onHover: onHover
    ) {
      Image(systemName: "doc.on.clipboard")
        .font(.system(size: 17))
        .foregroundStyle(.secondary)
        .frame(width: 28)

      VStack(alignment: .leading, spacing: 2) {
        Text(entry.text.replacingOccurrences(of: "\n", with: " "))
          .lineLimit(2)
          .frame(maxWidth: .infinity, alignment: .leading)

        Text(entry.capturedAt, style: .relative)
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
  }
}
