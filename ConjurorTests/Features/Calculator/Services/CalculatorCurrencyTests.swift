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

    #expect(engine.evaluate("100 USD to EUR", currencyRates: rates)?.copyText == "80.00 EUR")
    #expect(engine.evaluate("$50 in GBP", currencyRates: rates)?.copyText == "25.00 GBP")
    #expect(engine.evaluate("20 EUR → ¥", currencyRates: rates)?.copyText == "2500 JPY")
  }

  @Test("Arithmetic amounts convert, with the source currency attached or chained")
  func testArithmeticCurrencyAmounts() {
    let rates = CurrencyRates(
      base: "USD",
      rates: ["EUR": 0.8, "GBP": 0.5],
      rateDate: "2026-08-11",
      fetchedAt: Date()
    )

    let chained = engine.evaluate("500*21 in gbp in usd", currencyRates: rates)
    #expect(chained?.copyText == "21000.00 USD")
    #expect(chained?.sourceDisplay == "10,500")
    #expect(chained?.sourceBadge == "GBP")
    #expect(chained?.targetBadge == "USD")
    #expect(
      engine.evaluate("500*21 in GBP to EUR", currencyRates: rates)?.copyText == "16800.00 EUR"
    )
    #expect(engine.evaluate("500*21 GBP in USD", currencyRates: rates)?.copyText == "21000.00 USD")
    #expect(engine.evaluate("£(2 + 3) * 10 → $", currencyRates: rates)?.copyText == "100.00 USD")
    #expect(engine.evaluate("500*21 in gbp in parsecs", currencyRates: rates) == nil)
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

    let result = localeEngine.evaluate("1 CAD", currencyRates: rates)
    #expect(result?.copyText == "0.40 GBP")
    #expect(result?.sourceBadge == "CAD")
    #expect(result?.targetBadge == "GBP")
    #expect(localeEngine.evaluate("1 GBP", currencyRates: rates) == nil)
  }

  @Test("Disabled or unavailable currency conversion stays silent")
  func testUnavailableCurrency() {
    #expect(engine.evaluate("100 USD to EUR", currencyRates: nil) == nil)
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
      engine.evaluate("123.456 USD to EUR", currencyRates: rates)?.copyText == "123.46 EUR"
    )
    #expect(
      engine.evaluate("1 IDR to USD", currencyRates: rates)?.copyText == "0.00005539 USD"
    )
    #expect(engine.evaluate("1 USD to JPY", currencyRates: rates)?.copyText == "123 JPY")
    #expect(engine.evaluate("1 USD to BHD", currencyRates: rates)?.copyText == "0.376 BHD")
  }
}
