/// An action on running apps, other than switching to the selected one with Return.
enum RunningApplicationCommand: Equatable {
  case forceQuit
  case hide
  case hideOthers
  case quit
  case quitAll
  case relaunch
}

/// A destructive action waiting for Return to confirm or Escape to cancel. It names its target
/// processes so a later selection change cannot redirect it.
enum RunningApplicationConfirmation: Equatable {
  case forceQuit(RunningApplication)
  case quitAll([RunningApplication])

  var targets: [RunningApplication] {
    switch self {
    case .forceQuit(let application): [application]
    case .quitAll(let applications): applications
    }
  }

  var message: String {
    switch self {
    case .forceQuit(let application):
      "Force quit \(application.displayName)? Unsaved changes will be lost."
    case .quitAll(let applications):
      "Quit \(applications.count) \(applications.count == 1 ? "app" : "apps")? "
        + applications.map(\.displayName).joined(separator: ", ")
    }
  }

  var confirmTitle: String {
    switch self {
    case .forceQuit: "Force Quit"
    case .quitAll: "Quit All"
    }
  }
}
