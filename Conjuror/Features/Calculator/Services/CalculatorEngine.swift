import Foundation

struct CalculatorEngine: CurrencyCalculatorEvaluating {
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

  func evaluate(_ expression: String) -> CalculatorResult? {
    evaluate(expression, currencySource: .off)
  }

  func evaluate(
    _ expression: String,
    currencySource: CurrencySource
  ) -> CalculatorResult? {
    let trimmedExpression = expression.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedExpression.isEmpty else {
      return nil
    }

    if let relativeDateResult = CalculatorRelativeDateEvaluator(
      currentDate: currentDate(),
      timeZone: currentTimeZone(),
      localeIdentifier: formattingOptions.localeIdentifier
    ).evaluate(trimmedExpression) {
      return relativeDateResult
    }

    if let timeZoneResult = CalculatorTimeZoneEvaluator(
      currentDate: currentDate(),
      currentTimeZone: currentTimeZone()
    ).evaluate(trimmedExpression) {
      return timeZoneResult
    }

    if let currencyResult = CalculatorCurrencyEvaluator(
      formattingOptions: formattingOptions,
      localeCurrencyCode: localeCurrencyCode,
      source: currencySource
    ).evaluate(trimmedExpression) {
      return currencyResult
    }

    if let radixResult = CalculatorRadixEvaluator().evaluate(trimmedExpression) {
      return radixResult
    }

    if let quantityResult = CalculatorQuantityEvaluator(
      formattingOptions: formattingOptions
    ).evaluate(trimmedExpression) {
      return quantityResult
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

protocol CalculatorEvaluating {
  func evaluate(_ expression: String) -> CalculatorResult?
}

protocol CurrencyCalculatorEvaluating: CalculatorEvaluating {
  func evaluate(
    _ expression: String,
    currencySource: CurrencySource
  ) -> CalculatorResult?
}

struct CalculatorNumberFormatter {
  private static let maximumExactInteger = 9_007_199_254_740_992.0

  let options: CalculatorFormattingOptions

  func string(
    from value: Double,
    usesGroupingSeparator: Bool
  ) -> String? {
    let normalizedValue = value == 0 ? 0 : value
    let locale = Locale(identifier: options.localeIdentifier)
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

    let ungroupedText = ungrouped(text, locale: locale)
    return usesGroupingSeparator ? grouped(ungroupedText, locale: locale) : ungroupedText
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
    let locale = Locale(identifier: options.localeIdentifier)
    let fractionDigits = currencyFractionDigits(for: currencyCode, locale: locale)
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

    let ungroupedText = ungrouped(text, locale: locale)
    return usesGroupingSeparator ? grouped(ungroupedText, locale: locale) : ungroupedText
  }

  private func currencyFractionDigits(for code: String, locale: Locale) -> Int {
    let formatter = NumberFormatter()
    formatter.locale = locale
    formatter.numberStyle = .currency
    formatter.currencyCode = code
    return formatter.maximumFractionDigits
  }

  private func ungrouped(_ text: String, locale: Locale) -> String {
    let formatter = NumberFormatter()
    formatter.locale = locale
    guard let groupingSeparator = formatter.groupingSeparator else {
      return text
    }

    return text.replacingOccurrences(of: groupingSeparator, with: "")
  }

  private func grouped(_ text: String, locale: Locale) -> String {
    guard !text.contains("e"), !text.contains("E") else {
      return text
    }

    let formatter = NumberFormatter()
    formatter.locale = locale
    let decimalSeparator = formatter.decimalSeparator ?? "."
    let groupingSeparator = formatter.groupingSeparator ?? ","
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

private enum CalculatorToken: Equatable {
  case divide
  case end
  case identifier(String)
  case leftParenthesis
  case minus
  case modulo
  case multiply
  case number(Double, isScientific: Bool)
  case of
  case percent
  case plus
  case power
  case rightParenthesis
}

private enum CalculatorLexer {
  static func tokenize(_ expression: String) -> [CalculatorToken]? {
    let canonicalExpression =
      expression
      .lowercased()
      .replacingOccurrences(of: "multiplied by", with: "*")
      .replacingOccurrences(of: "divided by", with: "/")
      .replacingOccurrences(of: "to the power of", with: "^")
      .replacingOccurrences(of: "raised to", with: "^")
    let characters = Array(canonicalExpression)
    var index = 0
    var tokens = [CalculatorToken]()

    while index < characters.count {
      let character = characters[index]
      if character.isWhitespace {
        index += 1
        continue
      }

      if character.isNumber || character == "." {
        guard let token = numberToken(in: characters, index: &index) else {
          return nil
        }
        tokens.append(token)
        continue
      }

      if character.isLetter || character == "π" {
        let start = index
        while index < characters.count,
          characters[index].isLetter || characters[index] == "π"
        {
          index += 1
        }
        let word = String(characters[start..<index])
        tokens.append(token(for: word))
        continue
      }

      switch character {
      case "+": tokens.append(.plus)
      case "-", "−": tokens.append(.minus)
      case "*", "×": tokens.append(.multiply)
      case "/", "÷": tokens.append(.divide)
      case "^": tokens.append(.power)
      case "%": tokens.append(.percent)
      case "(": tokens.append(.leftParenthesis)
      case ")": tokens.append(.rightParenthesis)
      default: return nil
      }
      index += 1
    }

    tokens.append(.end)
    return tokens
  }

  private static func numberToken(
    in characters: [Character],
    index: inout Int
  ) -> CalculatorToken? {
    let start = index
    var hasDecimalPoint = false
    var hasDigit = false

    while index < characters.count {
      let character = characters[index]
      if character.isNumber {
        hasDigit = true
        index += 1
      } else if character == ".", !hasDecimalPoint {
        hasDecimalPoint = true
        index += 1
      } else {
        break
      }
    }

    guard hasDigit else {
      return nil
    }

    var isScientific = false
    if index < characters.count, characters[index] == "e" {
      var exponentEnd = index + 1
      if exponentEnd < characters.count,
        characters[exponentEnd] == "+" || characters[exponentEnd] == "-"
      {
        exponentEnd += 1
      }
      let digitStart = exponentEnd
      while exponentEnd < characters.count, characters[exponentEnd].isNumber {
        exponentEnd += 1
      }
      if exponentEnd > digitStart {
        isScientific = true
        index = exponentEnd
      }
    }

    guard let value = Double(String(characters[start..<index])) else {
      return nil
    }
    return .number(value, isScientific: isScientific)
  }

  private static func token(for word: String) -> CalculatorToken {
    switch word {
    case "plus": .plus
    case "minus": .minus
    case "times": .multiply
    case "over": .divide
    case "mod": .modulo
    case "of": .of
    default: .identifier(word)
    }
  }
}

private struct CalculatorParser {
  private struct ParsedValue {
    let number: Double
    let isPercent: Bool
  }

  private static let constants = [
    "e": M_E,
    "pi": Double.pi,
    "π": Double.pi,
  ]

  private static let functions = Set(["abs", "sqrt"])

  private(set) var hasCalculatorIntent = false

  private let tokens: [CalculatorToken]
  private var index = 0

  private var currentToken: CalculatorToken {
    tokens[index]
  }

  init(tokens: [CalculatorToken]) {
    self.tokens = tokens
  }

  mutating func parse() -> Double? {
    guard let value = parseAddition(), currentToken == .end else {
      return nil
    }
    return value.number
  }

  private mutating func parseAddition() -> ParsedValue? {
    guard var left = parseMultiplication() else {
      return nil
    }

    while currentToken == .plus || currentToken == .minus {
      let operation = currentToken
      hasCalculatorIntent = true
      advance()
      guard let right = parseMultiplication() else {
        return nil
      }

      if left.isPercent, right.isPercent {
        let number =
          operation == .plus
          ? left.number + right.number
          : left.number - right.number
        left = ParsedValue(number: number, isPercent: true)
      } else {
        let rightNumber =
          right.isPercent
          ? left.number * right.number
          : right.number
        let number =
          operation == .plus
          ? left.number + rightNumber
          : left.number - rightNumber
        left = ParsedValue(number: number, isPercent: false)
      }
    }

    return left
  }

  private mutating func parseMultiplication() -> ParsedValue? {
    guard var left = parseUnary() else {
      return nil
    }

    while true {
      let operation = currentToken
      if operation == .multiply || operation == .divide
        || operation == .modulo || operation == .of
      {
        hasCalculatorIntent = true
        advance()
        guard let right = parseUnary() else {
          return nil
        }

        switch operation {
        case .multiply, .of:
          left = ParsedValue(
            number: left.number * right.number,
            isPercent: false
          )
        case .divide:
          guard right.number != 0 else {
            return nil
          }
          left = ParsedValue(
            number: left.number / right.number,
            isPercent: false
          )
        case .modulo:
          guard right.number != 0 else {
            return nil
          }
          left = ParsedValue(
            number: left.number.truncatingRemainder(dividingBy: right.number),
            isPercent: false
          )
        default:
          return nil
        }
      } else if startsImplicitMultiplication(currentToken) {
        hasCalculatorIntent = true
        guard let right = parseUnary() else {
          return nil
        }
        left = ParsedValue(
          number: left.number * right.number,
          isPercent: false
        )
      } else {
        return left
      }
    }
  }

  private mutating func parseUnary() -> ParsedValue? {
    if currentToken == .plus {
      advance()
      return parseUnary()
    }
    if currentToken == .minus {
      advance()
      guard let value = parseUnary() else {
        return nil
      }
      return ParsedValue(number: -value.number, isPercent: value.isPercent)
    }
    return parsePower()
  }

  private mutating func parsePower() -> ParsedValue? {
    guard let left = parsePostfix() else {
      return nil
    }
    guard currentToken == .power else {
      return left
    }

    hasCalculatorIntent = true
    advance()
    guard let right = parseUnary() else {
      return nil
    }
    return ParsedValue(
      number: Foundation.pow(left.number, right.number),
      isPercent: false
    )
  }

  private mutating func parsePostfix() -> ParsedValue? {
    guard var value = parsePrimary() else {
      return nil
    }
    while currentToken == .percent {
      hasCalculatorIntent = true
      advance()
      value = ParsedValue(number: value.number / 100, isPercent: true)
    }
    return value
  }

  private mutating func parsePrimary() -> ParsedValue? {
    switch currentToken {
    case .number(let number, let isScientific):
      if isScientific {
        hasCalculatorIntent = true
      }
      advance()
      return ParsedValue(number: number, isPercent: false)
    case .leftParenthesis:
      advance()
      guard let value = parseAddition(), currentToken == .rightParenthesis else {
        return nil
      }
      advance()
      return value
    case .identifier(let name):
      return parseIdentifier(name)
    default:
      return nil
    }
  }

  private mutating func parseIdentifier(_ name: String) -> ParsedValue? {
    if let constant = Self.constants[name] {
      hasCalculatorIntent = true
      advance()
      return ParsedValue(number: constant, isPercent: false)
    }

    guard Self.functions.contains(name) else {
      return nil
    }
    hasCalculatorIntent = true
    advance()

    let argument: ParsedValue
    if currentToken == .leftParenthesis {
      advance()
      guard let parsedArgument = parseAddition(), currentToken == .rightParenthesis else {
        return nil
      }
      advance()
      argument = parsedArgument
    } else {
      guard let parsedArgument = parseUnary() else {
        return nil
      }
      argument = parsedArgument
    }

    let number: Double
    switch name {
    case "abs": number = Swift.abs(argument.number)
    case "sqrt":
      guard argument.number >= 0 else {
        return nil
      }
      number = Foundation.sqrt(argument.number)
    default: return nil
    }
    return ParsedValue(number: number, isPercent: false)
  }

  private func startsImplicitMultiplication(_ token: CalculatorToken) -> Bool {
    switch token {
    case .leftParenthesis:
      true
    case .identifier(let name):
      Self.constants[name] != nil || Self.functions.contains(name)
    default:
      false
    }
  }

  private mutating func advance() {
    index += 1
  }
}
