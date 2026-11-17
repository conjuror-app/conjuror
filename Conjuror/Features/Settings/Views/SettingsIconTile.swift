import SwiftUI

/// A settings section's symbol on its coloured rounded tile.
struct SettingsIconTile: View {
  let section: SettingsSection
  var size: CGFloat = 22

  var body: some View {
    Image(systemName: section.systemImage)
      .font(.system(size: size * 0.55, weight: .semibold))
      .foregroundStyle(.white)
      .frame(width: size, height: size)
      .background(
        section.tint.gradient,
        in: RoundedRectangle(cornerRadius: size * 0.27, style: .continuous)
      )
      .accessibilityHidden(true)
  }
}
