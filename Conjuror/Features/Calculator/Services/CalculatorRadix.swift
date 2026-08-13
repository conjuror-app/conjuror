import Foundation

struct CalculatorRadixEvaluator {
  func evaluate(_ expression: String) -> CalculatorResult? {
    let trimmedExpression = expression.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedExpression.isEmpty else {
      return nil
    }

    let canonicalExpression =
      trimmedExpression
      .lowercased()
      .replacingOccurrences(of: "->", with: " to ")
      .replacingOccurrences(of: "→", with: " to ")
    let parts = canonicalExpression.split(whereSeparator: { $0.isWhitespace }).map(String.init)

    let sourceText: String
    let sourceRadix: CalculatorRadix
    let targetRadix: CalculatorRadix

    switch parts.count {
    case 1:
      sourceText = parts[0]
      guard let inferredRadix = CalculatorRadix.inferred(from: sourceText),
        inferredRadix != .decimal
      else {
        return nil
      }
      sourceRadix = inferredRadix
      targetRadix = .decimal
    case 3:
      sourceText = parts[0]
      guard parts[1] == "to" || parts[1] == "in",
        let parsedTargetRadix = CalculatorRadix(alias: parts[2])
      else {
        return nil
      }
      sourceRadix = CalculatorRadix.inferred(from: sourceText) ?? .decimal
      targetRadix = parsedTargetRadix
    default:
      return nil
    }

    guard sourceRadix != targetRadix,
      let value = sourceRadix.parse(sourceText),
      let sourceDisplay = sourceRadix.format(value),
      let display = targetRadix.format(value)
    else {
      return nil
    }

    return CalculatorResult(
      expression: trimmedExpression,
      display: display,
      copyText: display,
      sourceDisplay: sourceDisplay,
      sourceBadge: sourceRadix.badge,
      targetBadge: targetRadix.badge
    )
  }
}

private enum CalculatorRadix: Int {
  case binary = 2
  case octal = 8
  case decimal = 10
  case hexadecimal = 16

  static func inferred(from text: String) -> CalculatorRadix? {
    let unsigned = text.hasPrefix("-") || text.hasPrefix("+") ? String(text.dropFirst()) : text
    if unsigned.hasPrefix("0b") { return .binary }
    if unsigned.hasPrefix("0o") { return .octal }
    if unsigned.hasPrefix("0x") { return .hexadecimal }
    return nil
  }

  var badge: String {
    switch self {
    case .binary: "BIN"
    case .octal: "OCT"
    case .decimal: "DEC"
    case .hexadecimal: "HEX"
    }
  }

  var prefix: String {
    switch self {
    case .binary: "0b"
    case .octal: "0o"
    case .decimal: ""
    case .hexadecimal: "0x"
    }
  }

  init?(alias: String) {
    switch alias {
    case "bin", "binary": self = .binary
    case "oct", "octal": self = .octal
    case "dec", "decimal": self = .decimal
    case "hex", "hexadecimal": self = .hexadecimal
    default: return nil
    }
  }

  func parse(_ text: String) -> Int64? {
    var digits = text
    var isNegative = false
    if digits.hasPrefix("-") || digits.hasPrefix("+") {
      isNegative = digits.hasPrefix("-")
      digits.removeFirst()
    }

    if self != .decimal {
      guard digits.hasPrefix(prefix) else {
        return nil
      }
      digits.removeFirst(prefix.count)
    }

    guard !digits.isEmpty else {
      return nil
    }

    let magnitudeLimit = isNegative ? UInt64(Int64.max) + 1 : UInt64(Int64.max)
    guard let magnitude = UInt64(digits, radix: rawValue), magnitude <= magnitudeLimit else {
      return nil
    }
    if isNegative, magnitude == UInt64(Int64.max) + 1 {
      return Int64.min
    }
    let value = Int64(magnitude)
    return isNegative ? -value : value
  }

  func format(_ value: Int64) -> String? {
    if self == .decimal {
      return String(value)
    }

    let magnitude = value.magnitude
    let digits = String(magnitude, radix: rawValue, uppercase: self == .hexadecimal)
    return (value < 0 ? "-" : "") + prefix + digits
  }
}
