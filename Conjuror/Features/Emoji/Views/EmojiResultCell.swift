import SwiftUI

struct EmojiResultCell: View {
  let emoji: Emoji
  let isSelected: Bool
  let onHover: () -> Void
  let onCopy: () -> Void

  var body: some View {
    Button(action: onCopy) {
      Text(emoji.value)
        .font(.system(size: 27))
        .frame(maxWidth: .infinity)
        .frame(height: 42)
        .background(
          isSelected ? Color.accentColor.opacity(0.18) : Color.clear,
          in: RoundedRectangle(cornerRadius: 7)
        )
    }
    .buttonStyle(.plain)
    .onHover { isHovering in
      if isHovering { onHover() }
    }
    .help(emoji.name)
    .accessibilityLabel(emoji.name)
    .accessibilityHint("Copies the emoji")
  }
}
