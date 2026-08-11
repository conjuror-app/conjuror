import AppKit
import SwiftUI

struct SettingsView: View {
  @ObservedObject var store: SettingsStore
  @ObservedObject var hotKeyStore: HotKeyStore
  @ObservedObject var currencyRateStore: CurrencyRateStore

  var body: some View {
    TabView {
      GeneralSettingsView(
        store: store,
        hotKeyStore: hotKeyStore,
        currencyRateStore: currencyRateStore
      )
      .tabItem {
        Label("General", systemImage: "gearshape")
      }

      AboutSettingsView()
        .tabItem {
          Label("About", systemImage: "info.circle")
        }
    }
    .frame(width: 460, height: 300)
  }
}

private struct GeneralSettingsView: View {
  @ObservedObject var store: SettingsStore
  @ObservedObject var hotKeyStore: HotKeyStore
  @ObservedObject var currencyRateStore: CurrencyRateStore

  var body: some View {
    VStack(alignment: .leading, spacing: 18) {
      HStack {
        VStack(alignment: .leading, spacing: 3) {
          Text("Keyboard shortcut")
          Text("Show or hide the launcher from anywhere.")
            .font(.caption)
            .foregroundStyle(.secondary)
        }

        Spacer()

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

      HStack {
        VStack(alignment: .leading, spacing: 3) {
          Text("Visible results")
          Text("Maximum results shown before scrolling.")
            .font(.caption)
            .foregroundStyle(.secondary)
        }

        Spacer()

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

      HStack {
        VStack(alignment: .leading, spacing: 3) {
          Text("Currency conversion")
          Text("Download daily exchange rates from Frankfurter. No search text is sent.")
            .font(.caption)
            .foregroundStyle(.secondary)
        }

        Spacer()

        Toggle(
          "Currency conversion",
          isOn: Binding(
            get: { currencyRateStore.isEnabled },
            set: { currencyRateStore.setEnabled($0) }
          )
        )
        .labelsHidden()
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
          currencyRateStore.setEnabled(false)
        }
      }
    }
    .padding(24)
  }

  @State private var hotKeyErrorMessage: String?
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
