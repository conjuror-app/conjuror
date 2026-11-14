import AppKit
import SwiftUI

struct ClipboardSettingsView: View {
  @ObservedObject var store: SettingsStore
  @ObservedObject var launcherStore: LauncherStore
  @ObservedObject var hotKeyStore: HotKeyStore

  var body: some View {
    SettingsPane {
      SettingsGroup(title: "History") {
        SettingsRow(
          title: "Clipboard history",
          description: "Keep text you copy so you can search and paste it again."
        ) {
          Toggle(
            "Clipboard history",
            isOn: Binding(
              get: { store.isClipboardHistoryEnabled },
              set: { isEnabled in
                store.setClipboardHistoryEnabled(isEnabled)
                hotKeyStore.register()
              }
            )
          )
          .labelsHidden()
        } footer: {
          SettingsNote(
            text:
              "History stays on this Mac. Conjuror skips text from password managers and anything an app marks as secret. Turning history off deletes it."
          )

          if store.isClipboardHistoryEnabled,
            NSPasteboard.general.accessBehavior == .alwaysDeny
          {
            SettingsNote(
              text:
                "macOS is blocking Conjuror from reading the clipboard. Allow pasteboard access for Conjuror in System Settings → Privacy & Security.",
              style: .warning
            )
          }
        }

        if store.isClipboardHistoryEnabled {
          SettingsRow(
            title: "Keep history for",
            description: "Older items are removed. Up to 1,000 items are kept."
          ) {
            Picker(
              "Keep history for",
              selection: Binding(
                get: { store.clipboardHistoryRetention },
                set: { store.setClipboardHistoryRetention($0) }
              )
            ) {
              ForEach(ClipboardHistoryRetention.allCases) { Text($0.title).tag($0) }
            }
            .labelsHidden()
            .frame(width: 140)
          }

          SettingsRow(
            title: "Clear history",
            description: "Delete every item in your clipboard history."
          ) {
            Button("Clear History…") { isConfirmingClear = true }
              .buttonStyle(SettingsDestructiveButtonStyle())
          }
          .confirmationDialog(
            "Clear clipboard history?",
            isPresented: $isConfirmingClear
          ) {
            Button(
              "Clear History",
              role: .destructive,
              action: launcherStore.clearClipboardHistory
            )
          } message: {
            Text("This deletes every item in your clipboard history.")
          }
        }
      }

      if store.isClipboardHistoryEnabled {
        SettingsGroup(title: "Shortcut") {
          ModeShortcutSettingsRow(
            description: "Open the launcher directly in clipboard history.",
            action: .clipboard,
            store: store,
            hotKeyStore: hotKeyStore
          )
        }

        SettingsGroup(title: "Pasting") {
          SettingsRow(
            title: "Paste into apps",
            description: canPaste
              ? "Return pastes the selected item into the app you were using."
              : "Allow Accessibility access so Return can paste. Until then, Return only copies."
          ) {
            if !canPaste {
              Button("Grant Access") {
                KeystrokeClipboardPaster.requestAccess()
              }
            }
          }
        }
      }
    }
    .onAppear { canPaste = launcherStore.pastesClipboardItems }
    .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification))
    {
      _ in
      canPaste = launcherStore.pastesClipboardItems
    }
  }

  @State private var canPaste = false
  @State private var isConfirmingClear = false
}
