import Foundation

struct CalculatorCurrencyEvaluator {
  let formattingOptions: CalculatorFormattingOptions
  let localeCurrencyCode: String?
  let rates: CurrencyRates?

  func evaluate(_ expression: String) -> CalculatorResult? {
    guard let rates,
      let conversion = parse(expression),
      let value = rates.convert(
        conversion.amount,
        from: conversion.sourceCode,
        to: conversion.targetCode
      )
    else {
      return nil
    }

    let formatter = CalculatorNumberFormatter(options: formattingOptions)

    guard
      let sourceDisplay = formatter.string(
        from: conversion.amount,
        usesGroupingSeparator: true
      ),
      let display = formatter.currencyString(
        from: value,
        currencyCode: conversion.targetCode,
        usesGroupingSeparator: true
      ),
      let copyValue = formatter.currencyString(
        from: value,
        currencyCode: conversion.targetCode,
        usesGroupingSeparator: false
      )
    else {
      return nil
    }

    return CalculatorResult(
      expression: expression,
      display: display,
      copyText: copyValue + " " + conversion.targetCode,
      sourceDisplay: sourceDisplay,
      sourceBadge: conversion.sourceCode,
      targetBadge: conversion.targetCode
    )
  }

  private func parse(_ expression: String) -> Conversion? {
    let (left, right) = CalculatorInput.splitConversion(expression)

    if let right {
      // "500*21 in GBP in USD" or "500*21 in GBP to USD" name the source currency
      // with a connector instead of attaching it to the amount.
      let (target, chainedTarget) = CalculatorInput.splitConversion(right)
      let (amountText, chainedSource) = CalculatorInput.splitConversion(left)

      if let chainedTarget {
        guard chainedSource == nil,
          let amount = arithmeticValue(left),
          let sourceCode = currencyCode(target),
          let targetCode = currencyCode(chainedTarget)
        else {
          return nil
        }

        return Conversion(amount: amount, sourceCode: sourceCode, targetCode: targetCode)
      }

      if let chainedSource {
        guard let amount = arithmeticValue(amountText),
          let sourceCode = currencyCode(chainedSource),
          let targetCode = currencyCode(right)
        else {
          return nil
        }

        return Conversion(amount: amount, sourceCode: sourceCode, targetCode: targetCode)
      }

      guard let source = parseAmount(left),
        let targetCode = currencyCode(right)
      else {
        return nil
      }

      return Conversion(
        amount: source.amount,
        sourceCode: source.code,
        targetCode: targetCode
      )
    }

    guard let source = parseAmount(left),
      let localeCurrencyCode = localeCurrencyCode?.uppercased(),
      currencyCode(localeCurrencyCode) != nil,
      source.code != localeCurrencyCode
    else {
      return nil
    }

    return Conversion(
      amount: source.amount,
      sourceCode: source.code,
      targetCode: localeCurrencyCode
    )
  }

  private func parseAmount(_ text: String) -> (amount: Double, code: String)? {
    let trimmed = text.trimmingCharacters(in: .whitespaces)

    if let first = trimmed.first,
      let code = Self.symbolCodes[first],
      let amount = arithmeticValue(String(trimmed.dropFirst()))
    {
      return (amount, code)
    }

    if let last = trimmed.last,
      let code = Self.symbolCodes[last],
      let amount = arithmeticValue(String(trimmed.dropLast()))
    {
      return (amount, code)
    }

    let parts = trimmed.split(whereSeparator: \.isWhitespace)

    guard parts.count >= 2 else {
      return nil
    }

    if let code = currencyCode(String(parts[parts.count - 1])),
      let amount = arithmeticValue(parts.dropLast().joined(separator: " "))
    {
      return (amount, code)
    }

    if let code = currencyCode(String(parts[0])),
      let amount = arithmeticValue(parts.dropFirst().joined(separator: " "))
    {
      return (amount, code)
    }

    return nil
  }

  /// Evaluates a plain number or an arithmetic expression such as `500*21`.
  private func arithmeticValue(_ text: String) -> Double? {
    let trimmed = text.trimmingCharacters(in: .whitespaces)

    if let number = Double(trimmed) {
      return number
    }

    guard let tokens = CalculatorLexer.tokenize(trimmed) else {
      return nil
    }

    var parser = CalculatorParser(tokens: tokens)

    guard let value = parser.parse(), value.isFinite else {
      return nil
    }

    return value
  }

  private func currencyCode(_ text: String) -> String? {
    let trimmed = text.trimmingCharacters(in: .whitespaces)

    if trimmed.count == 1, let symbol = trimmed.first,
      let code = Self.symbolCodes[symbol]
    {
      return code
    }

    let code = trimmed.uppercased()

    guard code.count == 3, code.allSatisfy(\.isLetter) else {
      return nil
    }

    return code
  }
}

private extension CalculatorCurrencyEvaluator {
  struct Conversion {
    let amount: Double
    let sourceCode: String
    let targetCode: String
  }

  static let symbolCodes: [Character: String] = [
    "$": "USD",
    "€": "EUR",
    "£": "GBP",
    "¥": "JPY",
    "₹": "INR",
    "₩": "KRW",
    "₽": "RUB",
    "฿": "THB",
    "₺": "TRY",
    "₴": "UAH",
    "₫": "VND",
  ]
}
