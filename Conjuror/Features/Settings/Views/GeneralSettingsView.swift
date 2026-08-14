import SwiftUI

struct GeneralSettingsView: View {
  @ObservedObject var store: SettingsStore
  @ObservedObject var hotKeyStore: HotKeyStore
  @ObservedObject var launchAtLoginStore: LaunchAtLoginStore

  var body: some View {
    SettingsPane {
      SettingsRow(
        title: "Keyboard shortcut",
        description: "Show or hide the launcher from anywhere."
      ) {
        ShortcutRecorder(
          configuration: store.hotKeyConfiguration,
          onChange: { configuration in
            hotKeyErrorMessage = hotKeyStore.updateConfiguration(configuration, for: .launcher)
            return hotKeyErrorMessage == nil
          },
          onRecordingChange: hotKeyStore.setShortcutRecording
        )
        .frame(width: 120, height: 28)
      }

      optionalShortcutRow(
        title: "Shortcuts mode",
        description: "Open the launcher directly in Apple Shortcuts mode.",
        action: .shortcuts,
        configuration: store.shortcutsHotKeyConfiguration
      )

      optionalShortcutRow(
        title: "Emoji mode",
        description: "Open the launcher directly in emoji mode.",
        action: .emoji,
        configuration: store.emojiHotKeyConfiguration
      )

      SettingsRow(
        title: "Launch at login",
        description: "Start Conjuror automatically when you log in."
      ) {
        LaunchAtLoginCheckbox(
          isOn: launchAtLoginStore.isEnabled,
          onChange: launchAtLoginStore.setEnabled
        )
        .frame(width: 18, height: 18)
      }

      if launchAtLoginStore.status == .requiresApproval {
        HStack {
          Label(
            "Allow Conjuror in System Settings to finish enabling launch at login.",
            systemImage: "exclamationmark.triangle"
          )
          .font(.caption)
          .foregroundStyle(.orange)

          Spacer()
          Button("Open Login Items Settings") {
            launchAtLoginStore.openLoginItemsSettings()
          }
        }
      }

      if let errorMessage = launchAtLoginStore.errorMessage {
        Label(errorMessage, systemImage: "exclamationmark.triangle")
          .font(.caption)
          .foregroundStyle(.red)
          .lineLimit(2)
      }

      SettingsRow(
        title: "Visible results",
        description: "Maximum results shown before scrolling."
      ) {
        HStack {
          Text("\(store.maximumVisibleResults)")
            .monospacedDigit()
            .frame(minWidth: 18)

          Stepper(
            "Visible results",
            value: Binding(
              get: { store.maximumVisibleResults },
              set: { value in
                store.setMaximumVisibleResults(value)
              }
            ),
            in: SettingsStore.maximumVisibleResultsRange
          )
          .labelsHidden()
        }
      }

      if let hotKeyErrorMessage {
        Label(hotKeyErrorMessage, systemImage: "exclamationmark.triangle")
          .font(.caption)
          .foregroundStyle(.red)
          .lineLimit(2)
      }

      Spacer()

      HStack {
        Spacer()
        Button("Reset to Defaults") {
          hotKeyErrorMessage = hotKeyStore.resetSettings()
        }
      }
    }
  }

  @State private var hotKeyErrorMessage: String?

  private func optionalShortcutRow(
    title: String,
    description: String,
    action: HotKeyAction,
    configuration: HotKeyConfiguration?
  ) -> some View {
    SettingsRow(title: title, description: description) {
      HStack {
        Toggle(
          title,
          isOn: Binding(
            get: { configuration != nil },
            set: { isEnabled in
              hotKeyErrorMessage = hotKeyStore.updateConfiguration(
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
            onChange: { newConfiguration in
              hotKeyErrorMessage = hotKeyStore.updateConfiguration(newConfiguration, for: action)
              return hotKeyErrorMessage == nil
            },
            onRecordingChange: hotKeyStore.setShortcutRecording
          )
          .frame(width: 120, height: 28)
        }
      }
    }
  }
}
