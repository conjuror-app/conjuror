import Carbon.HIToolbox

struct HotKeyConfiguration: Equatable {
  static let defaultValue = HotKeyConfiguration(
    keyCode: UInt32(kVK_Space),
    modifiers: UInt32(optionKey),
    displayName: "⌥ Space"
  )

  let keyCode: UInt32
  let modifiers: UInt32
  let displayName: String
}

enum HotKeyAction: CaseIterable, Hashable {
  case launcher
  case clipboard
  case shortcuts
  case emoji
  case files

  var defaultConfiguration: HotKeyConfiguration {
    switch self {
    case .launcher: .defaultValue
    case .clipboard:
      HotKeyConfiguration(
        keyCode: UInt32(kVK_ANSI_V),
        modifiers: UInt32(optionKey | shiftKey),
        displayName: "⌥⇧ V"
      )
    case .shortcuts:
      HotKeyConfiguration(
        keyCode: UInt32(kVK_Space),
        modifiers: UInt32(optionKey | shiftKey),
        displayName: "⌥⇧ Space"
      )
    case .emoji:
      HotKeyConfiguration(
        keyCode: UInt32(kVK_ANSI_E),
        modifiers: UInt32(optionKey | shiftKey),
        displayName: "⌥⇧ E"
      )
    case .files:
      HotKeyConfiguration(
        keyCode: UInt32(kVK_ANSI_F),
        modifiers: UInt32(cmdKey | shiftKey),
        displayName: "⌘⇧ F"
      )
    }
  }
}
