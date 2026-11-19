import SwiftUI

struct LauncherSearchField: View {
  @Binding var query: String
  let mode: LauncherMode
  let layout: LauncherLayout
  let resultCount: Int?
  let iconColor: Color
  let onEscape: () -> Void
  let escapeTitle: String
  let onOpenSelected: () -> Void
  let focusRequest: Int

  var body: some View {
    HStack(spacing: 8) {
      if layout.appearance != .typographic || mode != .applications {
        Image(systemName: mode.systemImage)
          .font(.system(size: layout.appearance.usesDetachedResults ? 17 : 14, weight: .medium))
          .foregroundStyle(iconColor)
          .frame(width: 18, height: 18)
          .help(mode.help)
          .accessibilityLabel(mode.help)
      }

      TextField(mode.placeholder, text: $text, axis: .horizontal)
        .focused($isFocused)
        .font(searchFont)
        .lineLimit(1)
        .textFieldStyle(.plain)
        .onChange(of: text) {
          query = text
          if text != query {
            text = query
          }
        }
        .onSubmit(onOpenSelected)

      if let resultCount, layout.appearance.usesTypography {
        Text(resultCount == 1 ? "1 result" : "\(resultCount) results")
          .font(.caption)
          .foregroundStyle(.secondary)
          .fixedSize()
      }

      if layout.appearance.usesDetachedResults {
        Button(action: onEscape) {
          Text("esc")
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.white.opacity(0.09), in: RoundedRectangle(cornerRadius: 5))
        }
        .buttonStyle(.plain)
        .help(escapeTitle)
        .accessibilityLabel(escapeTitle)
      } else if !text.isEmpty, !layout.appearance.usesTypography {
        Button {
          text = ""
        } label: {
          Image(systemName: "xmark.circle.fill")
            .font(.system(size: 13))
            .foregroundStyle(.tertiary)
        }
        .buttonStyle(.plain)
        .help("Clear search")
        .accessibilityLabel("Clear search")
      }
    }
    .padding(.horizontal, 2)
    .frame(height: layout.searchFieldHeight)
    .task {
      text = query
      isFocused = true
    }
    .onChange(of: query) {
      text = query
    }
    .onChange(of: focusRequest) {
      DispatchQueue.main.async {
        isFocused = true
      }
    }
  }

  @State private var text = ""
  @FocusState private var isFocused: Bool

  private var searchFont: Font {
    if layout.appearance.usesTypography { return .system(size: 30, weight: .light) }
    return .system(size: layout.appearance.usesDetachedResults ? 22 : 18)
  }
}
