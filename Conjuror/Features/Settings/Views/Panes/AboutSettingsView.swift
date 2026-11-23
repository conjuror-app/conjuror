import AppKit
import SwiftUI

struct AboutSettingsView: View {
  private static let githubURL = URL(string: "https://github.com/conjuror-app/conjuror")!
  private static let reportBugURL = URL(
    string: "https://github.com/conjuror-app/conjuror/issues"
  )!
  private static let licenceURL = URL(
    string: "https://github.com/conjuror-app/conjuror/blob/main/LICENSE"
  )!
  private static let frankfurterURL = URL(string: "https://frankfurter.dev")!
  private static let unicodeURL = URL(string: "https://unicode.org/emoji/charts/")!
  private static let copiedConfirmationDuration: Duration = .seconds(2)

  var body: some View {
    SettingsPane {
      SettingsHeaderCard(title: "Conjuror", subtitle: versionDescription) {
        Image(nsImage: NSApp.applicationIconImage)
          .resizable()
          .interpolation(.high)
          .accessibilityHidden(true)
      }

      SettingsGroup(title: "Support") {
        SettingsRow(
          title: "Report a bug",
          description: "Open an issue on GitHub."
        ) {
          Button("Report Bug") { openURL(Self.reportBugURL) }
        }

        SettingsRow(
          title: "Diagnostics",
          description: "Copy the app and macOS versions to paste into a bug report."
        ) {
          Button(didCopyDiagnostics ? "Copied" : "Copy Diagnostics") {
            copyDiagnostics()
          }
        }

        SettingsRow(
          title: "Source code",
          description: "Conjuror is open source."
        ) {
          Button("GitHub") { openURL(Self.githubURL) }
        }
      }

      PermissionsSettingsGroup()

      SettingsGroup(title: "Licence and credits") {
        SettingsRow(
          title: "Licence",
          description: "BSD 3-Clause. Copyright © 2026 Tom Bell."
        ) {
          Button("View Licence") { openURL(Self.licenceURL) }
        }

        SettingsRow(
          title: "Exchange rates",
          description: "Currency conversion uses daily rates from Frankfurter."
        ) {
          Button("Frankfurter") { openURL(Self.frankfurterURL) }
        }

        SettingsRow(
          title: "Emoji",
          description: "Emoji names and keywords come from Unicode's emoji and CLDR data."
        ) {
          Button("Unicode") { openURL(Self.unicodeURL) }
        }
      }
    }
  }

  @Environment(\.openURL) private var openURL
  @State private var didCopyDiagnostics = false

  private var versionDescription: String {
    "Version \(DiagnosticsReport.appVersion) (\(DiagnosticsReport.appBuild))"
  }

  private func copyDiagnostics() {
    let pasteboard = NSPasteboard.general
    pasteboard.clearContents()
    pasteboard.setString(DiagnosticsReport.text, forType: .string)
    didCopyDiagnostics = true

    Task {
      try? await Task.sleep(for: Self.copiedConfirmationDuration)
      didCopyDiagnostics = false
    }
  }
}

enum DiagnosticsReport {
  static var appVersion: String {
    Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
      ?? "Unknown"
  }

  static var appBuild: String {
    Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "Unknown"
  }

  static var text: String {
    """
    Conjuror \(appVersion) (\(appBuild))
    macOS \(ProcessInfo.processInfo.operatingSystemVersionString)
    Architecture: \(architecture)
    """
  }

  private static var architecture: String {
    #if arch(arm64)
    "Apple silicon"
    #else
    "Intel"
    #endif
  }
}
