import SwiftUI

struct LauncherSurfaceModifier: ViewModifier {
  func body(content: Content) -> some View {
    let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    content
      .clipShape(shape)
      .glassEffect(.regular, in: shape)
  }

  private let cornerRadius: CGFloat = 16
}
