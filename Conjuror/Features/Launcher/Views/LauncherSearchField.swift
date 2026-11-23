import SwiftUI

struct LauncherSearchField: View {
  @Binding var query: String
  let mode: LauncherMode
  let layout: LauncherLayout
  let iconColor: Color
  let onOpenSelected: () -> Void
  let onCycleMode: () -> Void
  let onReturnToRoot: () -> Void
  let focusRequest: Int

  var body: some View {
    HStack(spacing: layout.isCommandBar ? 10 : 8) {
      if layout.isCommandBar {
        if mode != .applications {
          Button(action: onReturnToRoot) {
            Image(systemName: "arrow.left")
              .font(.system(size: 11, weight: .semibold))
              .foregroundStyle(.secondary)
              .frame(width: 24, height: 24)
              .background(.primary.opacity(0.07), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
              .overlay {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                  .strokeBorder(.primary.opacity(0.08), lineWidth: 0.5)
              }
          }
          .buttonStyle(.plain)
          .help("Back to All Modes")
          .accessibilityLabel("Back to All Modes")
        }
      } else {
        Image(systemName: mode.systemImage)
          .font(.system(size: 14, weight: .medium))
          .foregroundStyle(iconColor)
          .frame(width: 18, height: 18)
          .help(mode.help)
          .accessibilityLabel(mode.help)
      }

      TextField(mode.placeholder, text: $text, axis: .horizontal)
        .focused($isFocused)
        .font(.system(size: layout.isCommandBar ? 16 : 18, weight: .regular))
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

      if layout.isCommandBar {
        Button(action: onCycleMode) {
          HStack(spacing: 6) {
            Circle()
              .fill(iconColor)
              .frame(width: 6, height: 6)

            Text(mode.displayName)
              .font(.system(size: 11.5, weight: .medium))
              .foregroundStyle(.primary.opacity(0.82))

            Text("Tab")
              .font(.system(size: 10, weight: .medium, design: .rounded))
              .foregroundStyle(.tertiary)
          }
          .padding(.horizontal, 9)
          .frame(height: 26)
          .background(.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
          .overlay {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
              .strokeBorder(.primary.opacity(0.09), lineWidth: 0.5)
          }
        }
        .buttonStyle(.plain)
        .help("\(mode.help) (Tab to switch)")
        .accessibilityLabel("\(mode.displayName). Press Tab to switch mode")
      }
    }
    .padding(.horizontal, layout.isCommandBar ? 4 : 2)
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
}
