enum LauncherMode: Equatable, Sendable {
  case applications
  case emoji
  case files
  case running
  case shortcuts
  case systemCommands

  /// The mode a query prefix switches to, such as `>` for shortcuts.
  static func requested(byPrefix prefix: Character) -> Self? {
    switch prefix {
    case ";": .applications
    case ">": .shortcuts
    case ":": .emoji
    case "/": .files
    case "!": .systemCommands
    case "@": .running
    default: nil
    }
  }

  /// The mode Tab cycles to, before checking whether that mode is enabled.
  var next: Self {
    switch self {
    case .applications: .shortcuts
    case .shortcuts: .emoji
    case .emoji: .files
    case .files: .running
    case .running: .systemCommands
    case .systemCommands: .applications
    }
  }

  var allowsHorizontalNavigation: Bool { self == .emoji }

  var systemImage: String {
    switch self {
    case .applications: "magnifyingglass"
    case .emoji: "face.smiling"
    case .files: "doc.text.magnifyingglass"
    case .running: "macwindow.on.rectangle"
    case .shortcuts: "square.stack.3d.up.fill"
    case .systemCommands: "power"
    }
  }

  var help: String {
    switch self {
    case .applications: "Application search mode"
    case .emoji: "Emoji search mode"
    case .files: "File and folder search mode"
    case .running: "Running apps mode"
    case .shortcuts: "Apple Shortcuts search mode"
    case .systemCommands: "System commands search mode"
    }
  }

  var placeholder: String {
    switch self {
    case .applications: "Search apps…"
    case .emoji: "Search emoji…"
    case .files: "Search files and folders…"
    case .running: "Search running apps…"
    case .shortcuts: "Search shortcuts…"
    case .systemCommands: "Search system commands…"
    }
  }

  var actionTitle: String {
    switch self {
    case .applications: "Launch application"
    case .emoji: "Copy emoji"
    case .files: "Open item"
    case .running: "Switch to app"
    case .shortcuts: "Run shortcut"
    case .systemCommands: "Run command"
    }
  }
}
