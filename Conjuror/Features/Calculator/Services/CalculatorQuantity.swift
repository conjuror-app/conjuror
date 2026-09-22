import Foundation

struct CalculatorQuantityEvaluator {
  let formattingOptions: CalculatorFormattingOptions

  func evaluate(_ expression: String) -> CalculatorResult? {
    guard let tokens = CalculatorQuantityLexer.tokenize(expression) else {
      return nil
    }

    var parser = CalculatorQuantityParser(tokens: tokens)

    guard let evaluation = parser.parse(), evaluation.value.isFinite else {
      return nil
    }

    let formatter = CalculatorNumberFormatter(options: formattingOptions)

    guard
      let sourceDisplay = formatter.string(
        from: evaluation.sourceValue,
        usesGroupingSeparator: true
      ),
      let displayValue = formatter.string(
        from: evaluation.value,
        usesGroupingSeparator: true
      ),
      let copyValue = formatter.string(
        from: evaluation.value,
        usesGroupingSeparator: false
      )
    else {
      return nil
    }

    return CalculatorResult(
      expression: expression,
      display: displayValue,
      copyText: copyValue + " " + evaluation.targetUnit.symbol,
      sourceDisplay: sourceDisplay,
      sourceBadge: evaluation.sourceBadge,
      targetBadge: evaluation.targetUnit.symbol
    )
  }
}
