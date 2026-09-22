import Foundation
import Testing

@testable import Conjuror

extension CalculatorEngineTests {
  @Test("Currency codes and symbols work when enabled")
  func testCurrencyCodesAndSymbols() {
    let rates = CurrencyRates(
      base: "USD",
      rates: ["EUR": 0.8, "GBP": 0.5, "JPY": 100],
      rateDate: "2026-08-11",
      fetchedAt: Date()
    )

    #expect(engine.evaluate("100 USD to EUR", currencySource: .on(rates))?.copyText == "80.00 EUR")
    #expect(engine.evaluate("$50 in GBP", currencySource: .on(rates))?.copyText == "25.00 GBP")
    #expect(engine.evaluate("20 EUR → ¥", currencySource: .on(rates))?.copyText == "2500 JPY")
  }

  @Test("Bare currency converts to the locale currency")
  func testBareCurrencyConvertsToLocaleCurrency() {
    let localeEngine = CalculatorEngine(
      formattingOptions: CalculatorFormattingOptions(
        localeIdentifier: "en_GB",
        maximumSignificantDigits: 10
      ),
      localeCurrencyCode: "GBP"
    )
    let rates = CurrencyRates(
      base: "USD",
      rates: ["CAD": 1.25, "GBP": 0.5],
      rateDate: "2026-08-11",
      fetchedAt: Date()
    )

    let result = localeEngine.evaluate("1 CAD", currencySource: .on(rates))
    #expect(result?.copyText == "0.40 GBP")
    #expect(result?.sourceBadge == "CAD")
    #expect(result?.targetBadge == "GBP")
    #expect(localeEngine.evaluate("1 GBP", currencySource: .on(rates)) == nil)
  }

  @Test("Disabled or unavailable currency conversion stays silent")
  func testUnavailableCurrency() {
    #expect(engine.evaluate("100 USD to EUR", currencySource: .off) == nil)
    #expect(engine.evaluate("100 USD to EUR", currencySource: .on(nil)) == nil)
  }

  @Test(
    "Target fraction digits are respected and values below the minor unit widen"
  )
  func testCurrencyPrecision() {
    let rates = CurrencyRates(
      base: "USD",
      rates: ["BHD": 0.376, "EUR": 1, "IDR": 18_053, "JPY": 123.456],
      rateDate: "2026-08-11",
      fetchedAt: Date()
    )

    #expect(
      engine.evaluate("123.456 USD to EUR", currencySource: .on(rates))?.copyText == "123.46 EUR"
    )
    #expect(
      engine.evaluate("1 IDR to USD", currencySource: .on(rates))?.copyText == "0.00005539 USD"
    )
    #expect(engine.evaluate("1 USD to JPY", currencySource: .on(rates))?.copyText == "123 JPY")
    #expect(engine.evaluate("1 USD to BHD", currencySource: .on(rates))?.copyText == "0.376 BHD")
  }
}
