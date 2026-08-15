import Foundation
import Testing

@testable import Conjuror

@Suite("Calculator Engine")
struct CalculatorEngineTests {
  let engine = CalculatorEngine(
    formattingOptions: CalculatorFormattingOptions(
      localeIdentifier: "en_US_POSIX",
      maximumSignificantDigits: 10
    )
  )

  @Test("Calculator input: conversion connectors share one canonical representation")
  func testConversionConnectorNormalization() {
    #expect(CalculatorInput.normalizingConversionConnectors(" 1 km → miles ") == "1 km  to  miles")
    #expect(CalculatorInput.normalizingConversionConnectors("1 km -> miles") == "1 km  to  miles")
    #expect(
      CalculatorInput.normalizingConversionConnectors("1 KM IN MILES", lowercased: true)
        == "1 km in miles"
    )
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

  func evaluate(_ expression: String) -> String? {
    engine.evaluate(expression)?.copyText
  }

  func relativeDateEngine(
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

  func timeZoneEngine(currentTimeZone: TimeZone) -> CalculatorEngine {
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
