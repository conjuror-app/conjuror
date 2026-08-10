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
        Image(systemName: mode == .applications ? "magnifyingglass" : "square.stack.3d.up.fill")
          .font(.system(size: 14, weight: .medium))
          .foregroundStyle(mode == .applications ? Color.secondary : Color.purple)
          .frame(width: 18, height: 18)
      }
      .buttonStyle(.plain)
      .help(mode == .applications ? "Search Apple Shortcuts (>)" : "Search applications")
      .accessibilityLabel(mode == .applications ? "Switch to shortcuts" : "Switch to applications")

      TextField(
        mode == .applications ? "Search apps…" : "Search shortcuts…",
        text: $text
      )
      .focused($isFocused)
      .font(.system(size: 18, weight: .regular))
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

  @State private var text = ""
  @FocusState private var isFocused: Bool
}
