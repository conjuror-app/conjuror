import SwiftUI

struct LauncherSurfaceModifier: ViewModifier {
  let appearance: LauncherAppearance
  let borderStyle: LauncherBorderStyle
  let customBorderColor: LauncherBorderColor

  private var cornerRadius: CGFloat {
    LauncherLayout(appearance: appearance).cornerRadius
  }

  private var borderColor: Color {
    LauncherAccentColor.color(
      for: borderStyle,
      customBorderColor: customBorderColor
    )
  }

  func body(content: Content) -> some View {
    let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    content
      .glassEffect(.regular, in: shape)
      .clipShape(shape)
      .overlay {
        if appearance == .commandBar {
          shape
            .strokeBorder(
              borderStyle == .disabled
                ? Color.primary.opacity(0.14)
                : borderColor.opacity(0.75),
              lineWidth: 1
            )
            .allowsHitTesting(false)
        } else if borderStyle != .disabled {
          shape
            .strokeBorder(borderColor.opacity(0.9), lineWidth: 1.25)
            .allowsHitTesting(false)
        }
      }
  }
}

enum LauncherAccentColor {
  static func color(
    for borderStyle: LauncherBorderStyle,
    customBorderColor: LauncherBorderColor
  ) -> Color {
    switch borderStyle {
    case .disabled: .secondary
    case .cyan: Color(red: 66 / 255, green: 216 / 255, blue: 239 / 255)
    case .purple: Color(red: 89 / 255, green: 70 / 255, blue: 216 / 255)
    case .yellow: Color(red: 243 / 255, green: 200 / 255, blue: 78 / 255)
    case .custom:
      Color(
        red: customBorderColor.red,
        green: customBorderColor.green,
        blue: customBorderColor.blue
      )
    }
  }
}
