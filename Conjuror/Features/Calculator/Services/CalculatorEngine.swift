import Foundation
import SoulverCore

final class CalculatorEngine {
  private let calculator: Calculator

  init(
    locale: Locale = .autoupdatingCurrent,
    updatesCurrencyRates: Bool = true
  ) {
    let rateProvider = ECBCurrencyRateProvider()
    var customization = EngineCustomization.standard.convertTo(locale: locale)
    customization.currencyRateProvider = rateProvider
    calculator = Calculator(customization: customization)

    if updatesCurrencyRates {
      Task {
        await rateProvider.updateRates()
      }
    }
  }

  func evaluate(_ expression: String) -> CalculatorResult? {
    let expression = expression.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !expression.isEmpty else {
      return nil
    }

    let result = calculator.calculate(expression)
    guard !result.isEmptyResult, !result.isPendingResult else {
      return nil
    }

    return CalculatorResult(
      expression: expression,
      display: result.stringValue,
      copyText: result.stringValue
    )
  }
}
