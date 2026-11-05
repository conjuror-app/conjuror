import AppKit
import SwiftUI

/// A quicklink result, or the web search fallback row when `isWebSearch` is set.
struct QuicklinkResultRow: View {
  let match: QuicklinkMatcher.Match
  let isWebSearch: Bool
  let layout: LauncherLayout
  let isSelected: Bool
  let onHover: () -> Void
  let onOpen: () -> Void

  var body: some View {
    SelectableResultRow(
      isSelected: isSelected,
      layout: layout,
      accessibilityLabel: title,
      accessibilityHint: "Opens the link",
      help: title,
      action: onOpen,
      onHover: onHover
    ) {
      icon
        .frame(width: layout.resultIconSize, height: layout.resultIconSize)

      VStack(alignment: .leading, spacing: 1) {
        Text(title)
          .font(.system(size: layout.resultFontSize, weight: .medium))
          .foregroundStyle(.primary)
          .lineLimit(1)

        if layout.appearance == .standard {
          Text(subtitle)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
      }

      Spacer()

      if layout.appearance == .minimal {
        Text(subtitle)
          .font(.caption2)
          .foregroundStyle(.secondary)
          .lineLimit(1)
      }

      if isWebSearch {
        Text("⌥↩")
          .font(.caption)
          .foregroundStyle(.secondary)
          .accessibilityLabel("Option-Return")
      }
    }
  }

  private var quicklink: Quicklink { match.quicklink }

  private var title: String {
    isWebSearch ? "Search \(quicklink.name) for “\(match.argument)”" : quicklink.name
  }

  private var subtitle: String {
    if isWebSearch { return "Web search" }

    if quicklink.acceptsQuery, !match.argument.isEmpty { return "Search for “\(match.argument)”" }

    return quicklink.keyword.map { "Quicklink · \($0)" } ?? "Quicklink"
  }

  /// The target app's icon, read locally. Nothing is fetched from the link's site.
  @ViewBuilder
  private var icon: some View {
    if let applicationURL {
      Image(nsImage: ApplicationIconCache.shared.icon(for: applicationURL))
        .resizable()
        .interpolation(.high)
    } else {
      Image(systemName: "globe")
        .resizable()
        .scaledToFit()
        .padding(4)
        .foregroundStyle(.secondary)
    }
  }

  private var applicationURL: URL? {
    switch quicklink.target {
    case .application(let path):
      URL(fileURLWithPath: path)
    case .defaultApplication:
      quicklink.url(argument: "").flatMap(NSWorkspace.shared.urlForApplication(toOpen:))
    }
  }
}
