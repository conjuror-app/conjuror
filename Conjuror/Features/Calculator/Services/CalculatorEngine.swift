import Foundation

struct CalculatorEngine {
  private let formattingOptions: CalculatorFormattingOptions
  private let currentDate: () -> Date
  private let currentTimeZone: () -> TimeZone
  private let localeCurrencyCode: String?

  init(
    formattingOptions: CalculatorFormattingOptions = .compact,
    localeCurrencyCode: String? = Locale.current.currency?.identifier,
    currentDate: @escaping () -> Date = { Date() },
    currentTimeZone: @escaping () -> TimeZone = { .autoupdatingCurrent }
  ) {
    self.formattingOptions = formattingOptions
    self.currentDate = currentDate
    self.currentTimeZone = currentTimeZone
    self.localeCurrencyCode = localeCurrencyCode
  }

  func evaluate(
    _ expression: String,
    currencyRates: CurrencyRates? = nil
  ) -> CalculatorResult? {
    let trimmedExpression = CalculatorInput.trimmed(expression)

    guard !trimmedExpression.isEmpty else {
      return nil
    }

    let now = currentDate()
    let timeZone = currentTimeZone()
    let evaluators: [(String) -> CalculatorResult?] = [
      CalculatorRelativeDateEvaluator(
        currentDate: now,
        timeZone: timeZone,
        formattingOptions: formattingOptions
      ).evaluate,
      CalculatorTimeZoneEvaluator(
        currentDate: now,
        currentTimeZone: timeZone
      ).evaluate,
      CalculatorCurrencyEvaluator(
        formattingOptions: formattingOptions,
        localeCurrencyCode: localeCurrencyCode,
        rates: currencyRates
      ).evaluate,
      CalculatorRadixEvaluator().evaluate,
      CalculatorQuantityEvaluator(formattingOptions: formattingOptions).evaluate,
    ]

    if let specializedResult = evaluators.lazy.compactMap({ $0(trimmedExpression) }).first {
      return specializedResult
    }

    guard let tokens = CalculatorLexer.tokenize(trimmedExpression) else {
      return nil
    }

    var parser = CalculatorParser(tokens: tokens)

    guard let value = parser.parse(),
      parser.hasCalculatorIntent,
      value.isFinite
    else {
      return nil
    }

    let formatter = CalculatorNumberFormatter(options: formattingOptions)

    guard let display = formatter.string(from: value, usesGroupingSeparator: true),
      let copyText = formatter.string(from: value, usesGroupingSeparator: false)
    else {
      return nil
    }

    return CalculatorResult(
      expression: trimmedExpression,
      display: display,
      copyText: copyText
    )
  }
}

enum CalculatorInput {
  static func trimmed(_ expression: String) -> String {
    expression.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  static func normalizeConversion(
    _ expression: String,
    lowercased: Bool = false
  ) -> String {
    let normalized = trimmed(expression)
      .replacingOccurrences(of: "→", with: " to ")
      .replacingOccurrences(of: "->", with: " to ")
    return lowercased ? normalized.lowercased() : normalized
  }

  /// Splits a conversion at its first " to " or " in ", ignoring case.
  /// The target is nil when the expression has no connector.
  static func splitConversion(_ expression: String) -> (source: String, target: String?) {
    let normalized = normalizeConversion(expression)

    guard
      let connector = normalized.range(of: " to ", options: .caseInsensitive)
        ?? normalized.range(of: " in ", options: .caseInsensitive)
    else {
      return (normalized, nil)
    }

    return (
      normalized[..<connector.lowerBound].trimmingCharacters(in: .whitespaces),
      normalized[connector.upperBound...].trimmingCharacters(in: .whitespaces)
    )
  }
}

struct CalculatorNumberFormatter {
  private static let maximumExactInteger = 9_007_199_254_740_992.0

  let options: CalculatorFormattingOptions
  private let locale: Locale
  private let decimalSeparator: String
  private let groupingSeparator: String?

  init(options: CalculatorFormattingOptions) {
    self.options = options
    locale = Locale(identifier: options.localeIdentifier)

    let formatter = NumberFormatter()
    formatter.locale = locale
    decimalSeparator = formatter.decimalSeparator ?? "."
    groupingSeparator = formatter.groupingSeparator
  }

  func string(
    from value: Double,
    usesGroupingSeparator: Bool
  ) -> String? {
    let normalizedValue = value == 0 ? 0 : value
    let text =
      if normalizedValue.rounded() == normalizedValue,
        Swift.abs(normalizedValue) <= Self.maximumExactInteger
      {
        String(format: "%.0f", locale: locale, normalizedValue)
      } else {
        String(
          format: "%.*g",
          locale: locale,
          options.maximumSignificantDigits,
          normalizedValue
        )
      }

    let ungroupedText = ungrouped(text)

    return usesGroupingSeparator ? grouped(ungroupedText) : ungroupedText
  }

  func currencyString(
    from value: Double,
    currencyCode: String,
    usesGroupingSeparator: Bool
  ) -> String? {
    guard value.isFinite else {
      return nil
    }

    let normalizedValue = value == 0 ? 0 : value
    let magnitude = Swift.abs(normalizedValue)
    let fractionDigits = currencyFractionDigits(for: currencyCode)
    let minorUnit = pow(10, -Double(fractionDigits))
    let text: String

    if magnitude < 1e-9 {
      text = String(format: "%.*f", locale: locale, fractionDigits, 0.0)
    } else if magnitude >= minorUnit {
      text = String(format: "%.*f", locale: locale, fractionDigits, normalizedValue)
    } else {
      let decimalPlaces = max(fractionDigits, 3 - Int(floor(log10(magnitude))))
      var formatted = String(
        format: "%.*f",
        locale: locale,
        decimalPlaces,
        normalizedValue
      )

      while formatted.hasSuffix("0") {
        formatted.removeLast()
      }

      text = formatted
    }

    let ungroupedText = ungrouped(text)

    return usesGroupingSeparator ? grouped(ungroupedText) : ungroupedText
  }

  private func currencyFractionDigits(for code: String) -> Int {
    let formatter = NumberFormatter()
    formatter.locale = locale
    formatter.numberStyle = .currency
    formatter.currencyCode = code

    return formatter.maximumFractionDigits
  }

  private func ungrouped(_ text: String) -> String {
    guard let groupingSeparator else {
      return text
    }

    return text.replacingOccurrences(of: groupingSeparator, with: "")
  }

  private func grouped(_ text: String) -> String {
    guard !text.contains("e"), !text.contains("E") else {
      return text
    }

    let groupingSeparator = groupingSeparator ?? ","
    let sign = text.hasPrefix("-") ? "-" : ""
    let unsigned = sign.isEmpty ? text : String(text.dropFirst())
    let parts = unsigned.components(separatedBy: decimalSeparator)
    let integer = parts[0]

    guard integer.count > 3 else {
      return text
    }

    var groupedInteger = ""

    for (index, digit) in integer.enumerated() {
      if index > 0, (integer.count - index).isMultiple(of: 3) {
        groupedInteger += groupingSeparator
      }

      groupedInteger.append(digit)
    }

    let fraction = parts.count > 1 ? decimalSeparator + parts[1] : ""

    return sign + groupedInteger + fraction
  }
}
