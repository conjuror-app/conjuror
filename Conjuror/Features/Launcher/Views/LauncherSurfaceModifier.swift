import SwiftUI

struct LauncherSurfaceModifier: ViewModifier {
  private let cornerRadius: CGFloat = 16

  @ViewBuilder
  func body(content: Content) -> some View {
    if #available(macOS 26.0, *) {
      let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
      content
        .clipShape(shape)
        .glassEffect(.regular, in: shape)
    } else {
      let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
      content
        .background(.regularMaterial, in: shape)
        .clipShape(shape)
        .overlay {
          shape.stroke(.quaternary, lineWidth: 1)
        }
    }
  }
}
