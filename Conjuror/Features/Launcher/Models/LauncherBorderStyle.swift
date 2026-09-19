enum LauncherBorderStyle: String, CaseIterable, Identifiable {
  case disabled
  case cyan
  case purple
  case yellow
  case custom

  var id: Self { self }

  var displayName: String {
    switch self {
    case .disabled: "Disabled"
    case .cyan: "Cyan"
    case .purple: "Purple"
    case .yellow: "Yellow"
    case .custom: "Custom"
    }
  }
}
