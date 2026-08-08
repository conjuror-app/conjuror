import AppKit
import Carbon.HIToolbox
import SwiftUI

struct SettingsView: View {
    @ObservedObject var store: SettingsStore
    let onHotKeyChange: (HotKeyConfiguration) -> String?
    let onShortcutRecordingChange: (Bool) -> Void
    let onReset: () -> String?

    var body: some View {
        TabView {
            GeneralSettingsView(
                store: store,
                onHotKeyChange: onHotKeyChange,
                onShortcutRecordingChange: onShortcutRecordingChange,
                onReset: onReset
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
    let onHotKeyChange: (HotKeyConfiguration) -> String?
    let onShortcutRecordingChange: (Bool) -> Void
    let onReset: () -> String?

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
                        hotKeyErrorMessage = onHotKeyChange(configuration)
                        return hotKeyErrorMessage == nil
                    },
                    onRecordingChange: onShortcutRecordingChange
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
                        set: store.setMaximumVisibleResults
                    ),
                    in: SettingsStore.maximumVisibleResultsRange
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
                    hotKeyErrorMessage = onReset()
                }
            }
        }
        .padding(24)
    }

    @State private var hotKeyErrorMessage: String?
}

private struct AboutSettingsView: View {
    private static let githubURL = URL(string: "https://github.com/tombell/conjuror")!
    private static let licenseURL = URL(string: "https://github.com/tombell/conjuror/blob/main/LICENSE")!

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
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
            ?? "Unknown"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
            ?? "Unknown"
        return "Version \(version) (\(build))"
    }
}

private struct ShortcutRecorder: NSViewRepresentable {
    let configuration: HotKeyConfiguration
    let onChange: (HotKeyConfiguration) -> Bool
    let onRecordingChange: (Bool) -> Void

    func makeNSView(context: Context) -> ShortcutRecorderButton {
        ShortcutRecorderButton(
            configuration: configuration,
            onChange: onChange,
            onRecordingChange: onRecordingChange
        )
    }

    func updateNSView(_ button: ShortcutRecorderButton, context: Context) {
        button.configuration = configuration
        button.onChange = onChange
        button.onRecordingChange = onRecordingChange
    }
}

private final class ShortcutRecorderButton: NSButton {
    private static func configuration(from event: NSEvent) -> HotKeyConfiguration? {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let shortcutFlags = flags.intersection([.command, .control, .option, .shift])
        guard !shortcutFlags.intersection([.command, .control, .option]).isEmpty,
              let keyName = keyName(for: event)
        else {
            return nil
        }

        return HotKeyConfiguration(
            keyCode: UInt32(event.keyCode),
            modifiers: carbonModifiers(from: shortcutFlags),
            displayName: displayName(modifiers: shortcutFlags, keyName: keyName)
        )
    }

    private static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var modifiers: UInt32 = 0
        if flags.contains(.control) {
            modifiers |= UInt32(controlKey)
        }
        if flags.contains(.option) {
            modifiers |= UInt32(optionKey)
        }
        if flags.contains(.shift) {
            modifiers |= UInt32(shiftKey)
        }
        if flags.contains(.command) {
            modifiers |= UInt32(cmdKey)
        }
        return modifiers
    }

    private static func displayName(
        modifiers: NSEvent.ModifierFlags,
        keyName: String
    ) -> String {
        var symbols = ""
        if modifiers.contains(.control) {
            symbols += "⌃"
        }
        if modifiers.contains(.option) {
            symbols += "⌥"
        }
        if modifiers.contains(.shift) {
            symbols += "⇧"
        }
        if modifiers.contains(.command) {
            symbols += "⌘"
        }
        return "\(symbols) \(keyName)"
    }

    private static func keyName(for event: NSEvent) -> String? {
        switch Int(event.keyCode) {
        case kVK_Space:
            return "Space"
        case kVK_Return:
            return "Return"
        case kVK_Tab:
            return "Tab"
        case kVK_Delete:
            return "Delete"
        case kVK_ForwardDelete:
            return "Forward Delete"
        case kVK_LeftArrow:
            return "←"
        case kVK_RightArrow:
            return "→"
        case kVK_DownArrow:
            return "↓"
        case kVK_UpArrow:
            return "↑"
        default:
            let characters = event.charactersIgnoringModifiers?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .uppercased()
            return characters?.isEmpty == false ? characters : nil
        }
    }

    var configuration: HotKeyConfiguration {
        didSet {
            guard !isRecording else {
                return
            }
            title = configuration.displayName
        }
    }

    var onChange: (HotKeyConfiguration) -> Bool
    var onRecordingChange: (Bool) -> Void

    override var acceptsFirstResponder: Bool { true }

    private var isRecording = false

    init(
        configuration: HotKeyConfiguration,
        onChange: @escaping (HotKeyConfiguration) -> Bool,
        onRecordingChange: @escaping (Bool) -> Void
    ) {
        self.configuration = configuration
        self.onChange = onChange
        self.onRecordingChange = onRecordingChange
        super.init(frame: .zero)

        title = configuration.displayName
        bezelStyle = .rounded
        setButtonType(.momentaryPushIn)
        target = self
        action = #selector(beginRecording)
        toolTip = "Click, then press a keyboard shortcut"
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func keyDown(with event: NSEvent) {
        guard isRecording else {
            super.keyDown(with: event)
            return
        }

        if Int(event.keyCode) == kVK_Escape {
            endRecording()
            return
        }

        guard let newConfiguration = Self.configuration(from: event) else {
            NSSound.beep()
            return
        }

        if onChange(newConfiguration) {
            configuration = newConfiguration
        }
        endRecording()
    }

    override func resignFirstResponder() -> Bool {
        let didResign = super.resignFirstResponder()
        if didResign {
            endRecording()
        }
        return didResign
    }

    @objc private func beginRecording() {
        guard !isRecording else {
            return
        }
        isRecording = true
        title = "Press shortcut…"
        guard window?.makeFirstResponder(self) == true else {
            isRecording = false
            title = configuration.displayName
            return
        }
        onRecordingChange(true)
    }

    private func endRecording() {
        guard isRecording else {
            return
        }
        isRecording = false
        title = configuration.displayName
        onRecordingChange(false)
    }
}
