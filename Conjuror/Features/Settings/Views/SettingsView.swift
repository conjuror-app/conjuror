import AppKit
import SwiftUI

struct SettingsView: View {
  @ObservedObject var store: SettingsStore
  @ObservedObject var hotKeyStore: HotKeyStore
  @ObservedObject var currencyRateStore: CurrencyRateStore

  var body: some View {
    TabView {
      GeneralSettingsView(store: store, hotKeyStore: hotKeyStore)
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
    .frame(width: 520, height: 280)
  }
}

private struct GeneralSettingsView: View {
  @ObservedObject var store: SettingsStore
  @ObservedObject var hotKeyStore: HotKeyStore

  var body: some View {
    SettingsPane {
      SettingsRow(
        title: "Keyboard shortcut",
        description: "Show or hide the launcher from anywhere."
      ) {
        ShortcutRecorder(
          configuration: store.hotKeyConfiguration,
          onChange: { configuration in
            hotKeyErrorMessage = hotKeyStore.updateConfiguration(configuration)
            return hotKeyErrorMessage == nil
          },
          onRecordingChange: hotKeyStore.setShortcutRecording
        )
        .frame(width: 120, height: 28)
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
