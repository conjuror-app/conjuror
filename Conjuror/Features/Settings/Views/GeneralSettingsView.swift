import AppKit
import SwiftUI

struct GeneralSettingsView: View {
  @ObservedObject var store: SettingsStore
  @ObservedObject var launchAtLoginStore: LaunchAtLoginStore

  var body: some View {
    SettingsPane {
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
        title: "Accent colour",
        description: "Set the colour of the launcher border and mode icons."
      ) {
        HStack {
          Picker(
            "Accent colour",
            selection: Binding(
              get: { store.launcherBorderStyle },
              set: { store.setLauncherBorderStyle($0) }
            )
          ) {
            ForEach(LauncherBorderStyle.allCases) { style in
              Label {
                Text(style.displayName)
              } icon: {
                Image(nsImage: borderSwatch(for: style))
              }
              .tag(style)
            }
          }
          .labelsHidden()
          .frame(width: 110)

          if store.launcherBorderStyle == .custom {
            ColorPicker(
              "Custom accent colour",
              selection: customBorderColor,
              supportsOpacity: false
            )
            .labelsHidden()
          }
        }
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

      Spacer()
    }
  }

  private var customBorderColor: Binding<Color> {
    Binding(
      get: {
        Color(
          red: store.launcherCustomBorderColor.red,
          green: store.launcherCustomBorderColor.green,
          blue: store.launcherCustomBorderColor.blue
        )
      },
      set: { color in
        guard let color = NSColor(color).usingColorSpace(.sRGB) else { return }
        store.setLauncherCustomBorderColor(
          LauncherBorderColor(
            red: color.redComponent,
            green: color.greenComponent,
            blue: color.blueComponent
          )
        )
      }
    )
  }

  private func borderSwatch(for style: LauncherBorderStyle) -> NSImage {
    let image = NSImage(size: NSSize(width: 10, height: 10))
    image.lockFocus()

    let circle = NSBezierPath(ovalIn: NSRect(x: 1, y: 1, width: 8, height: 8))
    if style == .disabled {
      NSColor.secondaryLabelColor.setStroke()
      circle.lineWidth = 1
      circle.stroke()
    } else {
      let color = borderColorComponents(for: style)
      NSColor(
        srgbRed: color.red,
        green: color.green,
        blue: color.blue,
        alpha: 1
      ).setFill()
      circle.fill()
    }

    image.unlockFocus()
    image.isTemplate = false
    return image
  }

  private func borderColorComponents(for style: LauncherBorderStyle) -> LauncherBorderColor {
    switch style {
    case .disabled, .cyan: .default
    case .purple: LauncherBorderColor(red: 89 / 255, green: 70 / 255, blue: 216 / 255)
    case .yellow: LauncherBorderColor(red: 243 / 255, green: 200 / 255, blue: 78 / 255)
    case .custom: store.launcherCustomBorderColor
    }
  }
}
