import Foundation
import Testing

@testable import Conjuror

@Suite("Calculator Engine")
struct CalculatorEngineTests {
  private let engine = CalculatorEngine(
    locale: Locale(identifier: "en_US"),
    updatesCurrencyRates: false
  )

  @Test("SoulverCore evaluates arithmetic and natural-language operators")
  func evaluatesArithmeticAndNaturalLanguageOperators() {
    #expect(evaluate("2 + 3 * 4") == "14")
    #expect(evaluate("20 divided by 4") == "5")
  }

  @Test("SoulverCore evaluates natural-language calculations")
  func evaluatesNaturalLanguageCalculations() {
    #expect(evaluate("65 kg in pounds") == "143.3004704202 lb")
    #expect(evaluate("40 is what % of 90") == "44.4444444444%")
    #expect(evaluate("$150 is 25% on what") == "$120.00")
    #expect(evaluate("3:45pm + 4 hr 10 min") == "7:55 PM")
  }

  @Test("SoulverCore ignores comment words")
  func ignoresCommentWords() {
    #expect(evaluate("$10 for lunch + 15% tip") == "$11.50")
  }

  @Test("SoulverCore behavior is used for plain numbers and failures")
  func usesSoulverCoreBehaviorForPlainNumbersAndFailures() {
    #expect(evaluate("123") == "123")
    #expect(engine.evaluate("notes") == nil)
    #expect(evaluate("1 / 0") == "Error: divide by zero")
    #expect(engine.evaluate(" ") == nil)
  }

  @Test("SoulverCore uses the requested locale")
  func usesRequestedLocale() {
    let localizedEngine = CalculatorEngine(
      locale: Locale(identifier: "de_DE"),
      updatesCurrencyRates: false
    )

    #expect(localizedEngine.evaluate("1,2 + 3,4")?.copyText == "4,6")
  }

  private func evaluate(_ expression: String) -> String? {
    engine.evaluate(expression)?.copyText
  }
}
