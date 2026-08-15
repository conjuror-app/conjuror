import Foundation

struct CalculatorCurrencyEvaluator {
  let formattingOptions: CalculatorFormattingOptions
  let localeCurrencyCode: String?
  let source: CurrencySource

  func evaluate(_ expression: String) -> CalculatorResult? {
    guard case .on(let rates) = source,
      let conversion = parse(expression)
    else {
      return nil
    }

    guard let rates,
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
    let normalized = CalculatorInput.normalizingConversionConnectors(expression)
    let lowercased = normalized.lowercased()
    let connector = lowercased.range(of: " to ") ?? lowercased.range(of: " in ")

    if let connector {
      let left = String(normalized[..<connector.lowerBound])
        .trimmingCharacters(in: .whitespaces)
      let right = String(normalized[connector.upperBound...])
        .trimmingCharacters(in: .whitespaces)
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

    guard let source = parseAmount(normalized),
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
      let amount = Double(trimmed.dropFirst().trimmingCharacters(in: .whitespaces))
    {
      return (amount, code)
    }
    if let last = trimmed.last,
      let code = Self.symbolCodes[last],
      let amount = Double(trimmed.dropLast().trimmingCharacters(in: .whitespaces))
    {
      return (amount, code)
    }

    let parts = trimmed.split(whereSeparator: \.isWhitespace)
    guard parts.count == 2 else {
      return nil
    }
    if let amount = Double(parts[0]), let code = currencyCode(String(parts[1])) {
      return (amount, code)
    }
    if let code = currencyCode(String(parts[0])), let amount = Double(parts[1]) {
      return (amount, code)
    }
    return nil
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
