import Foundation

struct CalculatorFormattingOptions: Equatable, Sendable {
  static let compact = CalculatorFormattingOptions()

  let localeIdentifier: String
  let maximumSignificantDigits: Int

  init(
    localeIdentifier: String = Locale.current.identifier,
    maximumSignificantDigits: Int = 10
  ) {
    self.localeIdentifier = localeIdentifier
    self.maximumSignificantDigits = maximumSignificantDigits
  }
}
