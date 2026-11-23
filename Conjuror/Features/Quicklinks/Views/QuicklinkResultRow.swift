import AppKit
import SwiftUI

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

      if layout.isCommandBar {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
          Text(title)
            .font(.system(size: layout.resultFontSize, weight: .medium))
            .foregroundStyle(.primary)
            .lineLimit(1)

          if !isWebSearch, quicklink.acceptsQuery, !match.argument.isEmpty {
            Text("for “\(match.argument)”")
              .font(.system(size: 12))
              .foregroundStyle(.secondary)
              .lineLimit(1)
          }
        }

        Spacer()

        if !isWebSearch, let keyword = quicklink.keyword {
          Text(keyword)
            .font(.system(size: 10.5, weight: .medium, design: .monospaced))
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(.primary.opacity(0.07), in: RoundedRectangle(cornerRadius: 5, style: .continuous))
            .overlay {
              RoundedRectangle(cornerRadius: 5, style: .continuous)
                .strokeBorder(.primary.opacity(0.08), lineWidth: 0.5)
            }
        }

        if isWebSearch {
          Text("⌥↩")
            .font(.system(size: 10.5, weight: .medium, design: .rounded))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(.primary.opacity(0.07), in: RoundedRectangle(cornerRadius: 5, style: .continuous))
            .accessibilityLabel("Option-Return")
        }

        Text(isWebSearch ? "Web Search" : "Quicklink")
          .font(.system(size: 12))
          .foregroundStyle(.tertiary)
          .lineLimit(1)
      } else {
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
