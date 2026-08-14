import AppKit
import SwiftUI

struct SettingsView: View {
  @ObservedObject var store: SettingsStore
  @ObservedObject var hotKeyStore: HotKeyStore
  @ObservedObject var currencyRateStore: CurrencyRateStore
  @ObservedObject var launchAtLoginStore: LaunchAtLoginStore

  var body: some View {
    TabView {
      GeneralSettingsView(
        store: store,
        hotKeyStore: hotKeyStore,
        launchAtLoginStore: launchAtLoginStore
      )
      .tabItem {
        Label("General", systemImage: "gearshape")
      }

      EmojiSettingsView(store: store)
        .tabItem {
          Label("Emoji", systemImage: "face.smiling")
        }

      CalculatorSettingsView(currencyRateStore: currencyRateStore)
        .tabItem {
          Label("Calculator", systemImage: "function")
        }

      AboutSettingsView()
        .tabItem {
          Label("About", systemImage: "info.circle")
        }
    }
    .frame(width: 520, height: 400)
    .onAppear {
      launchAtLoginStore.refresh()
    }
  }
}

private struct GeneralSettingsView: View {
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

private struct LaunchAtLoginCheckbox: NSViewRepresentable {
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

private struct EmojiSettingsView: View {
  @ObservedObject var store: SettingsStore

  var body: some View {
    SettingsPane {
      SettingsRow(
        title: "Preferred skin tone",
        description: "Automatically apply this tone to emoji that support it."
      ) {
        Picker(
          "Emoji skin tone",
          selection: Binding(
            get: { store.preferredEmojiSkinTone },
            set: { skinTone in
              store.setPreferredEmojiSkinTone(skinTone)
            }
          )
        ) {
          ForEach(EmojiSkinTone.allCases) { skinTone in
            Text("\(skinTone.exampleEmoji)  \(skinTone.displayName)").tag(skinTone)
          }
        }
        .labelsHidden()
        .frame(width: 170)
      }

      Spacer()
    }
  }
}

private struct CalculatorSettingsView: View {
  @ObservedObject var currencyRateStore: CurrencyRateStore

  var body: some View {
    SettingsPane {
      SettingsRow(
        title: "Currency conversion",
        description: "Download daily exchange rates from Frankfurter. No search text is sent."
      ) {
        Toggle(
          "Currency conversion",
          isOn: Binding(
            get: { currencyRateStore.isEnabled },
            set: { isEnabled in
              currencyRateStore.setEnabled(isEnabled)
            }
          )
        )
        .labelsHidden()
      }

      Spacer()
    }
  }
}

private struct AboutSettingsView: View {
  private static let githubURL = URL(string: "https://github.com/tombell/conjuror")!
  private static let licenseURL = URL(
    string: "https://github.com/tombell/conjuror/blob/main/LICENSE"
  )!

  var body: some View {
    VStack(spacing: 12) {
      Image(nsImage: NSApp.applicationIconImage)
        .resizable()
        .interpolation(.high)
        .frame(width: 72, height: 72)

      Text("Conjuror")
        .font(.title2.weight(.semibold))

      Text(versionDescription)
        .font(.caption)
        .foregroundStyle(.secondary)

      HStack(spacing: 16) {
        Link("GitHub", destination: Self.githubURL)
        Link("License", destination: Self.licenseURL)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .padding(24)
  }

  private var versionDescription: String {
    let version =
      Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
      ?? "Unknown"
    let build =
      Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
      ?? "Unknown"
    return "Version \(version) (\(build))"
  }
}

private struct SettingsPane<Content: View>: View {
  @ViewBuilder let content: Content

  var body: some View {
    VStack(alignment: .leading, spacing: 20) {
      content
    }
    .padding(24)
  }
}

private struct SettingsRow<Content: View>: View {
  let title: String
  let description: String
  @ViewBuilder let content: Content

  var body: some View {
    HStack(alignment: .center) {
      VStack(alignment: .leading, spacing: 3) {
        Text(title)
        Text(description)
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      Spacer(minLength: 24)
      content
    }
  }
}
