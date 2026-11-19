enum LauncherAppearance: String, CaseIterable, Identifiable {
  case minimal
  case standard
  case typographic
  case floatingPill
  case pillTypographic

  static let defaultValue: Self = .minimal

  var id: Self { self }

  var displayName: String {
    switch self {
    case .standard: "Standard"
    case .minimal: "Minimal"
    case .typographic: "Typographic"
    case .floatingPill: "Floating pill"
    case .pillTypographic: "Pill + typographic"
    }
  }

  var usesTypography: Bool { self == .typographic || self == .pillTypographic }
  var usesDetachedResults: Bool { self == .floatingPill || self == .pillTypographic }
  var usesDarkMaterial: Bool { self != .minimal && self != .standard }
}
