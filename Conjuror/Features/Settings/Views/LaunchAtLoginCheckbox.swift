import AppKit
import SwiftUI

struct LaunchAtLoginCheckbox: NSViewRepresentable {
  @MainActor
  final class Coordinator: NSObject {
    var onChange: (Bool) -> Void

    init(onChange: @escaping (Bool) -> Void) {
      self.onChange = onChange
    }

    @objc func toggle(_ sender: NSButton) {
      onChange(sender.state == .on)
    }
  }

  let isOn: Bool
  let onChange: (Bool) -> Void

  func makeCoordinator() -> Coordinator {
    Coordinator(onChange: onChange)
  }

  func makeNSView(context: Context) -> NSButton {
    let button = NSButton(
      checkboxWithTitle: "",
      target: context.coordinator,
      action: #selector(Coordinator.toggle(_:))
    )
    button.setAccessibilityLabel("Launch at login")
    return button
  }

  func updateNSView(_ button: NSButton, context: Context) {
    button.state = isOn ? .on : .off
    context.coordinator.onChange = onChange
  }
}
