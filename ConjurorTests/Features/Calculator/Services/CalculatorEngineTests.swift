import XCTest

@testable import Conjuror

final class CalculatorEngineTests: XCTestCase {
  private let engine = CalculatorEngine(
    formattingOptions: CalculatorFormattingOptions(
      localeIdentifier: "en_US_POSIX",
      maximumFractionDigits: 10
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
    XCTAssertEqual(evaluate("2pi"), "6.2831853072")
    XCTAssertEqual(evaluate("4(2 + 3)"), "20")
  }

  func testScientificNotationSignalsCalculatorIntent() {
    let result = engine.evaluate("1e5")

    XCTAssertEqual(result?.display, "100,000")
    XCTAssertEqual(result?.copyText, "100000")
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
}
