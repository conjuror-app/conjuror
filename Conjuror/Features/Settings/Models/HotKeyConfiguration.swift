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
