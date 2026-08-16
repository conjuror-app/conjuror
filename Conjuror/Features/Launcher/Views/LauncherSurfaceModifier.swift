import SwiftUI

struct LauncherSurfaceModifier: ViewModifier {
  let borderStyle: LauncherBorderStyle
  let customBorderColor: LauncherBorderColor

  private let cornerRadius: CGFloat = 16

  private var borderColor: Color {
    switch borderStyle {
    case .disabled: .clear
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

  func body(content: Content) -> some View {
    let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    content
      .glassEffect(.regular, in: shape)
      .clipShape(shape)
      .overlay {
        if borderStyle != .disabled {
          shape
            .strokeBorder(borderColor.opacity(0.9), lineWidth: 1.25)
            .allowsHitTesting(false)
        }
      }
  }
}
