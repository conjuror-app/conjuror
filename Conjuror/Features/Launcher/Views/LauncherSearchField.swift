import SwiftUI

struct LauncherSearchField: View {
  @Binding var query: String
  let mode: LauncherMode
  let onToggleMode: () -> Void
  let onOpenSelected: () -> Void
  let focusRequest: Int

  var body: some View {
    HStack(spacing: 8) {
      Button(action: onToggleMode) {
        Image(systemName: modeIcon)
          .font(.system(size: 14, weight: .medium))
          .foregroundStyle(modeIconColor)
          .frame(width: 18, height: 18)
      }
      .buttonStyle(.plain)
      .help(mode == .applications ? "Search Apple Shortcuts (>)" : "Search applications")
      .accessibilityLabel(mode == .applications ? "Switch to shortcuts" : "Switch to applications")

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
    .frame(height: 38)
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
    case .emoji: "face.smiling"
    case .shortcuts: "square.stack.3d.up.fill"
    }
  }

  private var modeIconColor: Color {
    switch mode {
    case .applications: Color(red: 66 / 255, green: 216 / 255, blue: 239 / 255)
    case .emoji: Color(red: 243 / 255, green: 200 / 255, blue: 78 / 255)
    case .shortcuts: Color(red: 89 / 255, green: 70 / 255, blue: 216 / 255)
    }
  }

  private var placeholder: String {
    switch mode {
    case .applications: "Search apps…"
    case .emoji: "Search emoji…"
    case .shortcuts: "Search shortcuts…"
    }
  }

  @State private var text = ""
  @FocusState private var isFocused: Bool
}
