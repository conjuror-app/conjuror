import Foundation
import Testing

@testable import Conjuror

@Suite("Calculator Engine")
struct CalculatorEngineTests {
  private let engine = CalculatorEngine(
    formattingOptions: CalculatorFormattingOptions(
      localeIdentifier: "en_US_POSIX",
      maximumSignificantDigits: 10
    )
  )

  @Test("Calculator engine: relative dates support calendar units in both directions")
  func testRelativeDatesSupportCalendarUnitsInBothDirections() {
    let engine = relativeDateEngine(
      currentDate: "2024-02-29T15:30:00Z",
      timeZone: TimeZone(secondsFromGMT: 0)!
    )

    #expect(engine.evaluate("1 day from now")?.copyText == "Mar 1, 2024 at 3:30 PM")
    #expect(engine.evaluate("2 weeks ago")?.copyText == "Feb 15, 2024 at 3:30 PM")
    #expect(engine.evaluate("1 month from now")?.copyText == "Mar 29, 2024 at 3:30 PM")
    #expect(engine.evaluate("1 year ago")?.copyText == "Feb 28, 2023 at 3:30 PM")
  }

  @Test("Calculator engine: relative dates support fractional duration units")
  func testRelativeDatesSupportFractionalDurationUnits() {
    let engine = relativeDateEngine(
      currentDate: "2026-08-12T12:00:00Z",
      timeZone: TimeZone(secondsFromGMT: 0)!
    )

    #expect(engine.evaluate("1.5 hours from now")?.copyText == "Aug 12, 2026 at 1:30 PM")
    #expect(engine.evaluate("90 minutes ago")?.copyText == "Aug 12, 2026 at 10:30 AM")
    #expect(engine.evaluate(".5 days from now")?.copyText == "Aug 13, 2026 at 12:00 AM")
    #expect(engine.evaluate("1.5 weeks ago")?.copyText == "Aug 2, 2026 at 12:00 AM")
  }

  @Test("Calculator engine: whole days use calendar arithmetic across daylight saving time")
  func testRelativeDatesUseCalendarArithmeticAcrossDaylightSavingTime() {
    let engine = relativeDateEngine(
      currentDate: "2026-03-28T12:00:00Z",
      timeZone: TimeZone(identifier: "Europe/London")!
    )

    #expect(engine.evaluate("1 day from now")?.copyText == "Mar 29, 2026 at 12:00 PM")
  }

  @Test("Calculator engine: invalid relative dates stay silent")
  func testInvalidRelativeDatesStaySilent() {
    #expect((engine.evaluate("1.5 months from now")) == nil)
    #expect((engine.evaluate("0 days from now")) == nil)
    #expect((engine.evaluate("-5 days from now")) == nil)
    #expect((engine.evaluate("5 days later")) == nil)
    #expect((engine.evaluate("days from now")) == nil)
  }

  @Test("Calculator engine: explicit time-zone abbreviations use fixed offsets")
  func testExplicitTimeZoneAbbreviationsUseFixedOffsets() {
    let engine = timeZoneEngine(currentTimeZone: TimeZone(identifier: "Europe/London")!)

    let result = engine.evaluate("10:00 BST in EST")

    #expect(result?.sourceDisplay == "10:00")
    #expect(result?.sourceBadge == "BST")
    #expect(result?.display == "04:00")
    #expect(result?.targetBadge == "EST")
    #expect(result?.copyText == "04:00 EST")
  }

  @Test("Calculator engine: standard and daylight abbreviations use distinct offsets")
  func testStandardAndDaylightAbbreviationsHaveDistinctOffsets() {
    let engine = timeZoneEngine(currentTimeZone: TimeZone(secondsFromGMT: 0)!)

    #expect(engine.evaluate("10:00 EST in GMT")?.copyText == "15:00 GMT")
    #expect(engine.evaluate("10:00 EDT in GMT")?.copyText == "14:00 GMT")
    #expect(engine.evaluate("10:00 PST in GMT")?.copyText == "18:00 GMT")
    #expect(engine.evaluate("10:00 PDT in GMT")?.copyText == "17:00 GMT")
    #expect(engine.evaluate("10:00 CET in GMT")?.copyText == "09:00 GMT")
    #expect(engine.evaluate("10:00 CEST in GMT")?.copyText == "08:00 GMT")
    #expect(engine.evaluate("10:00 NZST in GMT")?.copyText == "22:00 GMT")
    #expect(engine.evaluate("10:00 NZDT in GMT")?.copyText == "21:00 GMT")
    #expect(engine.evaluate("10:00 NST in GMT")?.copyText == "13:30 GMT")
    #expect(engine.evaluate("10:00 NDT in GMT")?.copyText == "12:30 GMT")
  }

  @Test("Calculator engine: other macOS time-zone abbreviations are supported")
  func testTimeZoneConversionSupportsOtherMacOSTimeZoneAbbreviations() {
    let engine = timeZoneEngine(currentTimeZone: TimeZone(secondsFromGMT: 0)!)

    #expect(engine.evaluate("10:00 EAT in IST")?.copyText == "12:30 IST")
    #expect(engine.evaluate("10:00 SGT in WAT")?.copyText == "03:00 WAT")
  }

  @Test("Calculator engine: bare time-zone input converts to the current time zone")
  func testBareTimeZoneInputConvertsToCurrentTimeZone() {
    let engine = timeZoneEngine(currentTimeZone: TimeZone(identifier: "Europe/London")!)

    let result = engine.evaluate("12:00 PST")

    #expect(result?.sourceDisplay == "12:00")
    #expect(result?.sourceBadge == "PST")
    #expect(result?.display == "21:00")
    #expect(result?.targetBadge == "BST")
    #expect(result?.copyText == "21:00 BST")
  }

  @Test("Calculator engine: current time zone is used when the source is omitted")
  func testTimeZoneConversionUsesCurrentTimeZoneWhenSourceIsOmitted() {
    let engine = timeZoneEngine(currentTimeZone: TimeZone(identifier: "Europe/London")!)

    let result = engine.evaluate("1:00 pm in PDT")

    #expect(result?.sourceBadge == "BST")
    #expect(result?.display == "5:00 am")
    #expect(result?.copyText == "5:00 am PDT")
  }

  @Test("Calculator engine: current context refreshes between evaluations")
  func testTimeZoneConversionRefreshesCurrentContextBetweenEvaluations() {
    var currentDate = ISO8601DateFormatter().date(from: "2026-08-12T12:00:00Z")!
    var currentTimeZone = TimeZone(identifier: "Europe/London")!
    let engine = CalculatorEngine(
      currentDate: { currentDate },
      currentTimeZone: { currentTimeZone }
    )

    #expect(engine.evaluate("10:00 in UTC")?.copyText == "09:00 UTC")

    currentDate = ISO8601DateFormatter().date(from: "2026-10-26T12:00:00Z")!
    #expect(engine.evaluate("10:00 in UTC")?.copyText == "10:00 UTC")

    currentTimeZone = TimeZone(identifier: "Asia/Tokyo")!
    #expect(engine.evaluate("10:00 in UTC")?.copyText == "01:00 UTC")
  }

  @Test("Calculator engine: time-zone connectors and day wrapping are supported")
  func testTimeZoneConversionSupportsConnectorsAndWrapsAcrossDays() {
    let engine = timeZoneEngine(currentTimeZone: TimeZone(secondsFromGMT: 0)!)

    #expect(engine.evaluate("23:30 UTC → JST")?.copyText == "08:30 JST")
    #expect(engine.evaluate("9am GMT -> PDT")?.copyText == "2:00 am PDT")
  }

  @Test("Calculator engine: invalid time-zone input stays silent")
  func testInvalidTimeZoneInputStaysSilent() {
    #expect((engine.evaluate("25:00 GMT in EST")) == nil)
    #expect((engine.evaluate("10:60 GMT in EST")) == nil)
    #expect((engine.evaluate("10:00 XYZ in EST")) == nil)
    #expect((engine.evaluate("10:00 GMT in XYZ")) == nil)
    #expect((engine.evaluate("10:00 in")) == nil)
    #expect((engine.evaluate("10:00")) == nil)
  }

  @Test("Calculator engine: currency codes and symbols work when enabled")
  func testCurrencyConversionSupportsCodesAndSymbolsWhenEnabled() {
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

  @Test("Calculator engine: bare currency converts to the locale currency")
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
    #expect((localeEngine.evaluate("1 GBP", currencySource: .on(rates))) == nil)
  }

  @Test("Calculator engine: disabled or unavailable currency conversion stays silent")
  func testCurrencyConversionIsSilentWhenDisabledOrRatesUnavailable() {
    #expect((engine.evaluate("100 USD to EUR", currencySource: .off)) == nil)
    #expect((engine.evaluate("100 USD to EUR", currencySource: .on(nil))) == nil)
  }

  @Test("Calculator engine: integer radix conversions are evaluated")
  func testIntegerRadixConversions() {
    #expect(evaluate("255 to hex") == "0xFF")
    #expect(evaluate("255 in octal") == "0o377")
    #expect(evaluate("255 -> binary") == "0b11111111")
    #expect(evaluate("0b11111111 → decimal") == "255")
    #expect(evaluate("0o377 to hex") == "0xFF")
    #expect(evaluate("0xFF to oct") == "0o377")
    #expect(evaluate("42 to hexadecimal") == "0x2A")
    #expect(evaluate("42 to bin") == "0b101010")
  }

  @Test("Calculator engine: prefixed integers automatically convert to decimal")
  func testPrefixedIntegersAutomaticallyConvertToDecimal() {
    #expect(evaluate("0xFF") == "255")
    #expect(evaluate("0Xff") == "255")
    #expect(evaluate("0o52") == "42")
    #expect(evaluate("0b101010") == "42")
  }

  @Test("Calculator engine: negative radix conversions use sign-magnitude notation")
  func testNegativeRadixConversions() {
    #expect(evaluate("-42 to hex") == "-0x2A")
    #expect(evaluate("-42 to octal") == "-0o52")
    #expect(evaluate("-0x2A to decimal") == "-42")
    #expect(evaluate("-0o52 to binary") == "-0b101010")
    #expect(evaluate("-0b101010") == "-42")
  }

  @Test("Calculator engine: radix conversion handles integer boundaries")
  func testRadixConversionHandlesIntegerBoundaries() {
    #expect(evaluate("0 to hex") == "0x0")
    #expect(evaluate("9223372036854775807 to hex") == "0x7FFFFFFFFFFFFFFF")
    #expect(evaluate("-0x8000000000000000 to decimal") == "-9223372036854775808")
  }

  @Test("Calculator engine: invalid radix input stays silent")
  func testInvalidRadixInputStaysSilent() {
    #expect((engine.evaluate("42 to decimal")) == nil)
    #expect((engine.evaluate("1.5 to hex")) == nil)
    #expect((engine.evaluate("0x to decimal")) == nil)
    #expect((engine.evaluate("0xGG to decimal")) == nil)
    #expect((engine.evaluate("0o8 to decimal")) == nil)
    #expect((engine.evaluate("0b2 to decimal")) == nil)
    #expect((engine.evaluate("0xFF to")) == nil)
    #expect((engine.evaluate("0x8000000000000000 to decimal")) == nil)
    #expect((engine.evaluate("9223372036854775808 to hex")) == nil)
  }

  @Test("Calculator engine: arithmetic precedence and parentheses are evaluated")
  func testArithmeticPrecedenceAndParentheses() {
    #expect(evaluate("2 + 3 * 4") == "14")
    #expect(evaluate("(2 + 3) * 4") == "20")
    #expect(evaluate("-2^2") == "-4")
    #expect(evaluate("2^3^2") == "512")
  }

  @Test("Calculator engine: natural-language operators are recognized")
  func testNaturalLanguageOperators() {
    #expect(evaluate("2 plus 3 times 4") == "14")
    #expect(evaluate("20 divided by 4") == "5")
    #expect(evaluate("20 over 4") == "5")
    #expect(evaluate("10 mod 3") == "1")
    #expect(evaluate("2 to the power of 3") == "8")
  }

  @Test("Calculator engine: percentages use relative addition semantics")
  func testPercentagesHaveRelativeAdditionSemantics() {
    #expect(evaluate("100 + 15%") == "115")
    #expect(evaluate("100 - 15%") == "85")
    #expect(evaluate("123 + 25% + 10%") == "169.125")
    #expect(evaluate("123 - 25% - 10%") == "83.025")
    #expect(evaluate("123 + (25% + 10%)") == "166.05")
    #expect(evaluate("20% of 50") == "10")
    #expect(evaluate("10% + 5%") == "0.15")
  }

  @Test("Calculator engine: constants, functions, and implicit multiplication are evaluated")
  func testConstantsFunctionsAndImplicitMultiplication() {
    #expect(evaluate("sqrt 9 + abs(-5)") == "8")
    #expect(evaluate("2pi") == "6.283185307")
    #expect(evaluate("4(2 + 3)") == "20")
  }

  @Test("Calculator engine: scientific notation signals calculator intent")
  func testScientificNotationSignalsCalculatorIntent() {
    let result = engine.evaluate("1e5")

    #expect(result?.display == "100,000")
    #expect(result?.copyText == "100000")
  }

  @Test("Calculator engine: ambiguous, invalid, and incomplete input stays silent")
  func testAmbiguousInvalidAndIncompleteInputStaysSilent() {
    #expect((engine.evaluate("123")) == nil)
    #expect((engine.evaluate("(123)")) == nil)
    #expect((engine.evaluate("2 3")) == nil)
    #expect((engine.evaluate("2 +")) == nil)
    #expect((engine.evaluate("1 / 0")) == nil)
    #expect((engine.evaluate("sqrt(-1)")) == nil)
    #expect((engine.evaluate("1e400")) == nil)
    #expect((engine.evaluate("notes")) == nil)
  }

  @Test("Calculator engine: compact formatting uses ten significant digits")
  func testCompactFormattingUsesTenSignificantDigits() {
    let compactEngine = CalculatorEngine(
      formattingOptions: CalculatorFormattingOptions(localeIdentifier: "en_US_POSIX")
    )

    let result = compactEngine.evaluate("2 / 3")
    #expect(result?.display == "0.6666666667")
    #expect(result?.copyText == "0.6666666667")
  }

  @Test(
    "Calculator engine: target fraction digits are respected and values below the minor unit widen"
  )
  func testCurrencyFormattingUsesTargetFractionDigitsAndWidensBelowMinorUnit() {
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

  private func evaluate(_ expression: String) -> String? {
    engine.evaluate(expression)?.copyText
  }

  private func relativeDateEngine(
    currentDate: String,
    timeZone: TimeZone
  ) -> CalculatorEngine {
    CalculatorEngine(
      formattingOptions: CalculatorFormattingOptions(
        localeIdentifier: "en_US_POSIX",
        maximumSignificantDigits: 10
      ),
      currentDate: { ISO8601DateFormatter().date(from: currentDate)! },
      currentTimeZone: { timeZone }
    )
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
