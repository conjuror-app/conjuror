import Foundation

struct CalculatorFormattingOptions: Equatable, Sendable {
    static let compact = CalculatorFormattingOptions()

    let localeIdentifier: String
    let maximumFractionDigits: Int

    init(
        localeIdentifier: String = Locale.current.identifier,
        maximumFractionDigits: Int = 10
    ) {
        self.localeIdentifier = localeIdentifier
        self.maximumFractionDigits = maximumFractionDigits
    }
}
