import SwiftUI

struct EmojiResultCell: View {
  let emoji: Emoji
  let layout: LauncherLayout
  let isSelected: Bool
  let onHover: () -> Void
  let onChoose: () -> Void

  var body: some View {
    Button(action: onChoose) {
      Text(emoji.value)
        .font(.system(size: layout.emojiFontSize))
        .frame(maxWidth: .infinity)
        .frame(height: layout.emojiRowHeight)
        .background(
          isSelected ? Color.accentColor.opacity(0.14) : Color.clear,
          in: RoundedRectangle(cornerRadius: 7)
        )
    }
    .buttonStyle(.plain)
    .onHover { isHovering in
      if isHovering { onHover() }
    }
    .help(emoji.name)
    .accessibilityLabel(emoji.name)
    .accessibilityHint("Pastes or copies the emoji")
  }
}
