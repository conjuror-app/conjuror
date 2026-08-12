import XCTest

@testable import Conjuror

final class CalculatorEngineTests: XCTestCase {
  private let engine = CalculatorEngine(
    formattingOptions: CalculatorFormattingOptions(
      localeIdentifier: "en_US_POSIX",
      maximumSignificantDigits: 10
    )
  )

  func testArithmeticPrecedenceAndParentheses() {
    XCTAssertEqual(evaluate("2 + 3 * 4"), "14")
    XCTAssertEqual(evaluate("(2 + 3) * 4"), "20")
    XCTAssertEqual(evaluate("-2^2"), "-4")
    XCTAssertEqual(evaluate("2^3^2"), "512")
  }

  func testNaturalLanguageOperators() {
    XCTAssertEqual(evaluate("2 plus 3 times 4"), "14")
    XCTAssertEqual(evaluate("20 divided by 4"), "5")
    XCTAssertEqual(evaluate("20 over 4"), "5")
    XCTAssertEqual(evaluate("10 mod 3"), "1")
    XCTAssertEqual(evaluate("2 to the power of 3"), "8")
  }

  func testPercentagesHaveRelativeAdditionSemantics() {
    XCTAssertEqual(evaluate("100 + 15%"), "115")
    XCTAssertEqual(evaluate("100 - 15%"), "85")
    XCTAssertEqual(evaluate("20% of 50"), "10")
    XCTAssertEqual(evaluate("10% + 5%"), "0.15")
  }

  func testConstantsFunctionsAndImplicitMultiplication() {
    XCTAssertEqual(evaluate("sqrt 9 + abs(-5)"), "8")
    XCTAssertEqual(evaluate("2pi"), "6.283185307")
    XCTAssertEqual(evaluate("4(2 + 3)"), "20")
  }

  func testScientificNotationSignalsCalculatorIntent() {
    let result = engine.evaluate("1e5")

    XCTAssertEqual(result?.display, "100,000")
    XCTAssertEqual(result?.copyText, "100000")
  }

  func testCompactFormattingUsesTenSignificantDigits() {
    let compactEngine = CalculatorEngine(
      formattingOptions: CalculatorFormattingOptions(localeIdentifier: "en_US_POSIX")
    )

    let result = compactEngine.evaluate("2 / 3")
    XCTAssertEqual(result?.display, "0.6666666667")
    XCTAssertEqual(result?.copyText, "0.6666666667")
  }

  func testExplicitTimeZoneAbbreviationsUseFixedOffsets() {
    let engine = timeZoneEngine(currentTimeZone: TimeZone(identifier: "Europe/London")!)

    let result = engine.evaluate("10:00 BST in EST")

    XCTAssertEqual(result?.sourceDisplay, "10:00")
    XCTAssertEqual(result?.sourceBadge, "BST")
    XCTAssertEqual(result?.display, "04:00")
    XCTAssertEqual(result?.targetBadge, "EST")
    XCTAssertEqual(result?.copyText, "04:00 EST")
  }

  func testStandardAndDaylightAbbreviationsHaveDistinctOffsets() {
    let engine = timeZoneEngine(currentTimeZone: TimeZone(secondsFromGMT: 0)!)

    XCTAssertEqual(engine.evaluate("10:00 EST in GMT")?.copyText, "15:00 GMT")
    XCTAssertEqual(engine.evaluate("10:00 EDT in GMT")?.copyText, "14:00 GMT")
    XCTAssertEqual(engine.evaluate("10:00 PST in GMT")?.copyText, "18:00 GMT")
    XCTAssertEqual(engine.evaluate("10:00 PDT in GMT")?.copyText, "17:00 GMT")
    XCTAssertEqual(engine.evaluate("10:00 CET in GMT")?.copyText, "09:00 GMT")
    XCTAssertEqual(engine.evaluate("10:00 CEST in GMT")?.copyText, "08:00 GMT")
    XCTAssertEqual(engine.evaluate("10:00 NZST in GMT")?.copyText, "22:00 GMT")
    XCTAssertEqual(engine.evaluate("10:00 NZDT in GMT")?.copyText, "21:00 GMT")
    XCTAssertEqual(engine.evaluate("10:00 NST in GMT")?.copyText, "13:30 GMT")
    XCTAssertEqual(engine.evaluate("10:00 NDT in GMT")?.copyText, "12:30 GMT")
  }

  func testTimeZoneConversionSupportsOtherMacOSTimeZoneAbbreviations() {
    let engine = timeZoneEngine(currentTimeZone: TimeZone(secondsFromGMT: 0)!)

    XCTAssertEqual(engine.evaluate("10:00 EAT in IST")?.copyText, "12:30 IST")
    XCTAssertEqual(engine.evaluate("10:00 SGT in WAT")?.copyText, "03:00 WAT")
  }

  func testTimeZoneConversionUsesCurrentTimeZoneWhenSourceIsOmitted() {
    let engine = timeZoneEngine(currentTimeZone: TimeZone(identifier: "Europe/London")!)

    let result = engine.evaluate("1:00 pm in PDT")

    XCTAssertEqual(result?.sourceBadge, "BST")
    XCTAssertEqual(result?.display, "5:00 am")
    XCTAssertEqual(result?.copyText, "5:00 am PDT")
  }

  func testTimeZoneConversionRefreshesCurrentContextBetweenEvaluations() {
    var currentDate = ISO8601DateFormatter().date(from: "2026-08-12T12:00:00Z")!
    var currentTimeZone = TimeZone(identifier: "Europe/London")!
    let engine = CalculatorEngine(
      currentDate: { currentDate },
      currentTimeZone: { currentTimeZone }
    )

    XCTAssertEqual(engine.evaluate("10:00 in UTC")?.copyText, "09:00 UTC")

    currentDate = ISO8601DateFormatter().date(from: "2026-10-26T12:00:00Z")!
    XCTAssertEqual(engine.evaluate("10:00 in UTC")?.copyText, "10:00 UTC")

    currentTimeZone = TimeZone(identifier: "Asia/Tokyo")!
    XCTAssertEqual(engine.evaluate("10:00 in UTC")?.copyText, "01:00 UTC")
  }

  func testTimeZoneConversionSupportsConnectorsAndWrapsAcrossDays() {
    let engine = timeZoneEngine(currentTimeZone: TimeZone(secondsFromGMT: 0)!)

    XCTAssertEqual(engine.evaluate("23:30 UTC → JST")?.copyText, "08:30 JST")
    XCTAssertEqual(engine.evaluate("9am GMT -> PDT")?.copyText, "2:00 am PDT")
  }

  func testInvalidTimeZoneInputStaysSilent() {
    XCTAssertNil(engine.evaluate("25:00 GMT in EST"))
    XCTAssertNil(engine.evaluate("10:60 GMT in EST"))
    XCTAssertNil(engine.evaluate("10:00 XYZ in EST"))
    XCTAssertNil(engine.evaluate("10:00 GMT in XYZ"))
    XCTAssertNil(engine.evaluate("10:00 in"))
  }

  func testCurrencyConversionSupportsCodesAndSymbolsWhenEnabled() {
    let rates = CurrencyRates(
      base: "USD",
      rates: ["EUR": 0.8, "GBP": 0.5, "JPY": 100],
      rateDate: "2026-08-11",
      fetchedAt: Date()
    )

    XCTAssertEqual(
      engine.evaluate("100 USD to EUR", currencySource: .on(rates))?.copyText,
      "80.00 EUR"
    )
    XCTAssertEqual(
      engine.evaluate("$50 in GBP", currencySource: .on(rates))?.copyText,
      "25.00 GBP"
    )
    XCTAssertEqual(
      engine.evaluate("20 EUR → ¥", currencySource: .on(rates))?.copyText,
      "2500 JPY"
    )
  }

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
    XCTAssertEqual(result?.copyText, "0.40 GBP")
    XCTAssertEqual(result?.sourceBadge, "CAD")
    XCTAssertEqual(result?.targetBadge, "GBP")
    XCTAssertNil(localeEngine.evaluate("1 GBP", currencySource: .on(rates)))
  }

  func testCurrencyFormattingUsesTargetFractionDigitsAndWidensBelowMinorUnit() {
    let rates = CurrencyRates(
      base: "USD",
      rates: ["BHD": 0.376, "EUR": 1, "IDR": 18_053, "JPY": 123.456],
      rateDate: "2026-08-11",
      fetchedAt: Date()
    )

    XCTAssertEqual(
      engine.evaluate("123.456 USD to EUR", currencySource: .on(rates))?.copyText,
      "123.46 EUR"
    )
    XCTAssertEqual(
      engine.evaluate("1 IDR to USD", currencySource: .on(rates))?.copyText,
      "0.00005539 USD"
    )
    XCTAssertEqual(
      engine.evaluate("1 USD to JPY", currencySource: .on(rates))?.copyText,
      "123 JPY"
    )
    XCTAssertEqual(
      engine.evaluate("1 USD to BHD", currencySource: .on(rates))?.copyText,
      "0.376 BHD"
    )
  }

  func testCurrencyConversionIsSilentWhenDisabledOrRatesUnavailable() {
    XCTAssertNil(engine.evaluate("100 USD to EUR", currencySource: .off))
    XCTAssertNil(engine.evaluate("100 USD to EUR", currencySource: .on(nil)))
  }

  func testAmbiguousInvalidAndIncompleteInputStaysSilent() {
    XCTAssertNil(engine.evaluate("123"))
    XCTAssertNil(engine.evaluate("(123)"))
    XCTAssertNil(engine.evaluate("2 3"))
    XCTAssertNil(engine.evaluate("2 +"))
    XCTAssertNil(engine.evaluate("1 / 0"))
    XCTAssertNil(engine.evaluate("sqrt(-1)"))
    XCTAssertNil(engine.evaluate("1e400"))
    XCTAssertNil(engine.evaluate("notes"))
  }

  private func evaluate(_ expression: String) -> String? {
    engine.evaluate(expression)?.copyText
  }

  private func timeZoneEngine(currentTimeZone: TimeZone) -> CalculatorEngine {
    CalculatorEngine(
      formattingOptions: CalculatorFormattingOptions(
        localeIdentifier: "en_US_POSIX",
        maximumSignificantDigits: 10
      ),
      currentDate: { ISO8601DateFormatter().date(from: "2026-08-12T12:00:00Z")! },
      currentTimeZone: { currentTimeZone }
    )
  }
}
