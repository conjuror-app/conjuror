import AppKit
import ApplicationServices
import SwiftUI

/// Lists the macOS permissions Conjuror can use, with their state where macOS reports it.
struct PermissionsSettingsGroup: View {
  var body: some View {
    SettingsGroup(title: "Permissions") {
      SettingsRow(
        title: "Accessibility",
        description: "Lets Return paste a clipboard item into the app you were using."
      ) {
        HStack(spacing: 10) {
          PermissionStatusLabel(status: isAccessibilityAllowed ? .allowed : .notAllowed)

          if isAccessibilityAllowed {
            Button("Open Settings") { open(.accessibility) }
          } else {
            Button("Grant Access") { KeystrokeClipboardPaster.requestAccess() }
          }
        }
      }

      SettingsRow(
        title: "Paste from other apps",
        description: "Lets clipboard history read the text you copy."
      ) {
        HStack(spacing: 10) {
          PermissionStatusLabel(status: pasteboardStatus)

          if pasteboardStatus != .notAskedYet {
            Button("Open Settings") { open(.pasteboard) }
          }
        }
      } footer: {
        if pasteboardStatus == .notAskedYet {
          SettingsNote(
            text:
              "Conjuror appears in System Settings after macOS first asks, when clipboard history reads text copied from another app."
          )
        }
      }

      SettingsRow(
        title: "Protected folders",
        description:
          "Lets file search include Desktop, Documents, Downloads, and iCloud Drive."
      ) {
        Button("Grant Access") { FileAccessAuthorizer.requestAccess() }
      } footer: {
        SettingsNote(
          text:
            "macOS asks once per folder and doesn't tell Conjuror what you chose. Review it in System Settings → Privacy & Security → Files & Folders."
        )
      }

      SettingsRow(
        title: "Automation",
        description:
          "Lets Conjuror run Apple Shortcuts, empty the Trash, and toggle dark mode. macOS asks the first time each is used."
      ) {
        Button("Open Settings") { open(.automation) }
      }
    }
    .onAppear(perform: refresh)
    .onReceive(
      NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
    ) { _ in
      refresh()
    }
  }

  @State private var isAccessibilityAllowed = false
  @State private var pasteboardStatus = PermissionStatus.asks

  private func refresh() {
    isAccessibilityAllowed = AXIsProcessTrusted()
    pasteboardStatus =
      switch NSPasteboard.general.accessBehavior {
      case .alwaysAllow: .allowed
      case .alwaysDeny: .notAllowed
      case .default: .notAskedYet
      default: .asks
      }
  }

  private func open(_ pane: PrivacyPane) {
    guard let url = pane.url else { return }

    NSWorkspace.shared.open(url)
  }
}

/// Shows whether macOS allows a permission, in the style of the Permissions group.
struct PermissionStatusLabel: View {
  let status: PermissionStatus

  var body: some View {
    Label(status.title, systemImage: status.systemImage)
      .font(.callout)
      .foregroundStyle(status.tint)
  }
}

enum PermissionStatus {
  case allowed
  case asks
  case notAllowed
  case notAskedYet

  var title: String {
    switch self {
    case .allowed: "Allowed"
    case .asks: "Asks each time"
    case .notAllowed: "Not allowed"
    case .notAskedYet: "Not asked yet"
    }
  }

  var systemImage: String {
    switch self {
    case .allowed: "checkmark.circle.fill"
    case .asks: "questionmark.circle"
    case .notAllowed: "xmark.circle"
    case .notAskedYet: "circle.dashed"
    }
  }

  var tint: Color {
    switch self {
    case .allowed: .green
    case .asks: .secondary
    case .notAllowed: .orange
    case .notAskedYet: .secondary
    }
  }
}

/// A section of System Settings → Privacy & Security.
private enum PrivacyPane: String {
  case accessibility = "Privacy_Accessibility"
  case automation = "Privacy_Automation"
  case pasteboard = "Privacy_Pasteboard"

  var url: URL? {
    URL(string: "x-apple.systempreferences:com.apple.preference.security?\(rawValue)")
  }
}
