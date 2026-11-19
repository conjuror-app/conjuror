import SwiftUI

struct LauncherSurfaceModifier: ViewModifier {
  let borderStyle: LauncherBorderStyle
  let customBorderColor: LauncherBorderColor
  let usesDarkMaterial: Bool
  var isCapsule = false

  private var borderColor: Color {
    LauncherAccentColor.color(
      for: borderStyle,
      customBorderColor: customBorderColor
    )
  }

  @ViewBuilder
  func body(content: Content) -> some View {
    if isCapsule {
      surface(content, in: Capsule())
    } else {
      surface(content, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
  }

  private func surface(_ content: Content, in shape: some InsettableShape) -> some View {
    content
      .glassEffect(usesDarkMaterial ? .regular.tint(.black.opacity(0.45)) : .regular, in: shape)
      .clipShape(shape)
      .overlay {
        if borderStyle != .disabled {
          shape
            .strokeBorder(borderColor.opacity(usesDarkMaterial ? 0.25 : 0.9), lineWidth: 1.25)
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
