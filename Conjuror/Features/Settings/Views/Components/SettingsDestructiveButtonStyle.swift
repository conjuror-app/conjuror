import SwiftUI

struct SettingsDestructiveButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .foregroundStyle(.red)
      .padding(.horizontal, 10)
      .padding(.vertical, 4)
      .background(.red.opacity(configuration.isPressed ? 0.28 : 0.16), in: Capsule())
      .contentShape(Capsule())
  }
}
