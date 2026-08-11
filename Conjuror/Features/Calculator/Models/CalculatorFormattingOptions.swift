import Foundation

struct CalculatorFormattingOptions: Equatable, Sendable {
  static let compact = CalculatorFormattingOptions()

  let localeIdentifier: String
  let maximumFractionDigits: Int

  init(
    localeIdentifier: String = Locale.current.identifier,
    maximumFractionDigits: Int = 6
  ) {
    self.localeIdentifier = localeIdentifier
    self.maximumFractionDigits = maximumFractionDigits
  }
}
