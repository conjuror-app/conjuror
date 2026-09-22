import AppKit

enum LauncherTextEditingCommand: Equatable {
  case copy
  case cut
  case paste
  case redo
  case selectAll
  case undo

  static func command(
    charactersIgnoringModifiers: String?,
    modifiers: NSEvent.ModifierFlags
  ) -> Self? {
    let key = charactersIgnoringModifiers?.lowercased()

    switch (modifiers, key) {
    case (.command, "a"): return .selectAll
    case (.command, "c"): return .copy
    case (.command, "v"): return .paste
    case (.command, "x"): return .cut
    case (.command, "z"): return .undo
    case ([.command, .shift], "z"): return .redo
    default: return nil
    }
  }

  var action: Selector {
    switch self {
    case .copy: #selector(NSText.copy(_:))
    case .cut: #selector(NSText.cut(_:))
    case .paste: #selector(NSText.paste(_:))
    case .redo: Selector(("redo:"))
    case .selectAll: #selector(NSText.selectAll(_:))
    case .undo: Selector(("undo:"))
    }
  }
}
