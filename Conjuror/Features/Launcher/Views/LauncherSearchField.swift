import SwiftUI

struct LauncherSearchField: View {
  @Binding var query: String
  let mode: LauncherMode
  let iconColor: Color
  let onOpenSelected: () -> Void
  let focusRequest: Int

  var body: some View {
    HStack(spacing: 8) {
      Image(systemName: modeIcon)
        .font(.system(size: 14, weight: .medium))
        .foregroundStyle(iconColor)
        .frame(width: 18, height: 18)
        .help(modeHelp)
        .accessibilityLabel(modeHelp)

      TextField(placeholder, text: $text, axis: .horizontal)
        .focused($isFocused)
        .font(.system(size: 18, weight: .regular))
        .lineLimit(1)
        .textFieldStyle(.plain)
        .onChange(of: text) {
          query = text
          if text != query {
            text = query
          }
        }
        .onSubmit(onOpenSelected)

      if !text.isEmpty {
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
    .frame(height: LauncherLayout.searchFieldHeight)
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

  private var modeIcon: String {
    switch mode {
    case .applications: "magnifyingglass"
    case .clipboard: "doc.on.clipboard"
    case .emoji: "face.smiling"
    case .files: "doc.text.magnifyingglass"
    case .shortcuts: "square.stack.3d.up.fill"
    }
  }

  private var modeHelp: String {
    switch mode {
    case .applications: "Application search mode"
    case .clipboard: "Clipboard history mode"
    case .emoji: "Emoji search mode"
    case .files: "File and folder search mode"
    case .shortcuts: "Apple Shortcuts search mode"
    }
  }

  private var placeholder: String {
    switch mode {
    case .applications: "Search apps…"
    case .clipboard: "Search clipboard history…"
    case .emoji: "Search emoji…"
    case .files: "Search files and folders…"
    case .shortcuts: "Search shortcuts…"
    }
  }

  @State private var text = ""
  @FocusState private var isFocused: Bool
}
