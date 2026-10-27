import SwiftUI

struct LauncherSearchField: View {
  @Binding var query: String
  let mode: LauncherMode
  let iconColor: Color
  let onOpenSelected: () -> Void
  let focusRequest: Int

  var body: some View {
    HStack(spacing: 8) {
      Image(systemName: mode.systemImage)
        .font(.system(size: 14, weight: .medium))
        .foregroundStyle(iconColor)
        .frame(width: 18, height: 18)
        .help(mode.help)
        .accessibilityLabel(mode.help)

      TextField(mode.placeholder, text: $text, axis: .horizontal)
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

  @State private var text = ""
  @FocusState private var isFocused: Bool
}
