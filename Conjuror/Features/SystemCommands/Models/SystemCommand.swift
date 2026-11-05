/// A fixed system action, such as locking the screen or emptying the Trash.
enum SystemCommand: String, CaseIterable, Identifiable, Sendable {
  case lockScreen = "lock-screen"
  case sleep
  case sleepDisplays = "sleep-displays"
  case startScreenSaver = "start-screen-saver"
  case showDesktop = "show-desktop"
  case toggleDarkMode = "toggle-dark-mode"
  case ejectAllDisks = "eject-all-disks"
  case emptyTrash = "empty-trash"
  case logOut = "log-out"
  case restart
  case shutDown = "shut-down"

  var id: String {
    rawValue
  }

  var persistenceKey: String {
    "system-command:\(rawValue)"
  }

  var title: String {
    switch self {
    case .lockScreen: "Lock Screen"
    case .sleep: "Sleep"
    case .sleepDisplays: "Sleep Displays"
    case .startScreenSaver: "Start Screen Saver"
    case .showDesktop: "Show Desktop"
    case .toggleDarkMode: "Toggle Dark Mode"
    case .ejectAllDisks: "Eject All Disks"
    case .emptyTrash: "Empty Trash"
    case .logOut: "Log Out"
    case .restart: "Restart"
    case .shutDown: "Shut Down"
    }
  }

  /// Other words that find the command, matched as secondary search text.
  var keywords: String {
    switch self {
    case .lockScreen: "lock"
    case .sleep: "suspend"
    case .sleepDisplays: "screen off monitor"
    case .startScreenSaver: "screensaver"
    case .showDesktop: "hide windows"
    case .toggleDarkMode: "appearance light theme"
    case .ejectAllDisks: "unmount volumes drives"
    case .emptyTrash: "bin delete"
    case .logOut: "logout sign out"
    case .restart: "reboot"
    case .shutDown: "shutdown power off"
    }
  }

  var systemImage: String {
    switch self {
    case .lockScreen: "lock.fill"
    case .sleep: "moon.fill"
    case .sleepDisplays: "display"
    case .startScreenSaver: "sparkles.tv"
    case .showDesktop: "menubar.dock.rectangle"
    case .toggleDarkMode: "circle.lefthalf.filled"
    case .ejectAllDisks: "eject.fill"
    case .emptyTrash: "trash.fill"
    case .logOut: "rectangle.portrait.and.arrow.right"
    case .restart: "arrow.clockwise"
    case .shutDown: "power"
    }
  }

  /// Whether the launcher asks for a second Return. Restart, Shut Down, and Log Out show the
  /// system's own confirmation dialog instead.
  var requiresConfirmation: Bool {
    switch self {
    case .ejectAllDisks, .emptyTrash: true
    default: false
    }
  }

  var confirmationTitle: String {
    "\(title) now?"
  }
}
