import AppKit
import SwiftUI

struct ModeShortcutSettingsRow: View {
  let description: String
  let action: HotKeyAction
  @ObservedObject var store: SettingsStore
  @ObservedObject var hotKeyStore: HotKeyStore

  var body: some View {
    SettingsRow(title: "Keyboard shortcut", description: description) {
      HStack {
        Toggle(
          "Keyboard shortcut",
          isOn: Binding(
            get: { configuration != nil },
            set: { isEnabled in
              errorMessage = hotKeyStore.updateConfiguration(
                isEnabled ? action.defaultConfiguration : nil,
                for: action
              )
            }
          )
        )
        .labelsHidden()

        if let configuration {
          ShortcutRecorder(
            configuration: configuration,
            allowsFunctionKey: true,
            onChange: { newConfiguration in
              errorMessage = hotKeyStore.updateConfiguration(newConfiguration, for: action)
              return errorMessage == nil
            },
            onRecordingChange: hotKeyStore.setShortcutRecording
          )
          .frame(width: 120, height: 28)
        }
      }
    } footer: {
      if let errorMessage {
        SettingsNote(text: errorMessage, style: .error)
      } else if configuration?.isFunctionKey == true, isGlobeActionEnabled {
        SettingsNote(
          text:
            "macOS also acts on the 🌐 key. Set “Press 🌐 key to” to “Do Nothing” in System Settings → Keyboard.",
          style: .warning
        )
      }
    }
    .onAppear(perform: refreshGlobeAction)
    .onReceive(
      NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
    ) { _ in
      refreshGlobeAction()
    }
  }

  private func refreshGlobeAction() {
    isGlobeActionEnabled = GlobeKeySystemAction.isEnabled
  }

  private var configuration: HotKeyConfiguration? {
    store.hotKeyConfiguration(for: action)
  }

  @State private var errorMessage: String?
  @State private var isGlobeActionEnabled = GlobeKeySystemAction.isEnabled
}
