import AppKit
import SwiftUI

struct GeneralSettingsView: View {
  @ObservedObject var store: SettingsStore
  @ObservedObject var launchAtLoginStore: LaunchAtLoginStore

  var body: some View {
    SettingsPane {
      SettingsGroup(title: "Startup") {
        SettingsRow(
          title: "Launch at login",
          description: "Start Conjuror automatically when you log in."
        ) {
          LaunchAtLoginCheckbox(
            isOn: launchAtLoginStore.isEnabled,
            onChange: launchAtLoginStore.setEnabled
          )
          .frame(width: 18, height: 18)
        } footer: {
          if launchAtLoginStore.status == .requiresApproval {
            HStack {
              SettingsNote(
                text: "Allow Conjuror in System Settings to finish enabling launch at login.",
                style: .warning
              )

              Spacer()
              Button("Open Login Items Settings") {
                launchAtLoginStore.openLoginItemsSettings()
              }
            }
          }

          if let errorMessage = launchAtLoginStore.errorMessage {
            SettingsNote(text: errorMessage, style: .error)
          }
        }
      }

      SettingsGroup(title: "Launcher") {
        SettingsRow(
          title: "Launcher appearance",
          description: "Choose the spacing and detail shown in the launcher."
        ) {
          Picker(
            "Launcher appearance",
            selection: Binding(
              get: { store.launcherAppearance },
              set: { store.setLauncherAppearance($0) }
            )
          ) {
            ForEach(LauncherAppearance.allCases) { appearance in
              Text(appearance.displayName).tag(appearance)
            }
          }
          .labelsHidden()
          .frame(width: 110)
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
      }
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
      NSColor(
        LauncherAccentColor.color(
          for: style,
          customBorderColor: store.launcherCustomBorderColor
        )
      ).setFill()
      circle.fill()
    }

    image.unlockFocus()
    image.isTemplate = false
    return image
  }
}
