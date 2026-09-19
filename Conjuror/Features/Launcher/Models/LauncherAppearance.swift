enum LauncherAppearance: String, CaseIterable, Identifiable {
  case standard
  case minimal

  var id: Self { self }

  var displayName: String {
    switch self {
    case .standard: "Standard"
    case .minimal: "Minimal"
    }
  }
}
