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
      sourceBadge: evaluation.sourceBadge,
      targetBadge: evaluation.targetUnit.symbol
    )
  }
}

private enum CalculatorQuantityDimension: Equatable {
  case data
  case duration
  case length
  case mass
  case temperature
  case volume
}

private struct CalculatorUnit: Equatable {
  let id: String
  let dimension: CalculatorQuantityDimension
  let symbol: String
  let aliases: [String]
  let scaleToBase: Double
  let offsetToBase: Double

  init(
    id: String,
    dimension: CalculatorQuantityDimension,
    symbol: String,
    aliases: [String],
    scaleToBase: Double,
    offsetToBase: Double = 0
  ) {
    self.id = id
    self.dimension = dimension
    self.symbol = symbol
    self.aliases = aliases
    self.scaleToBase = scaleToBase
    self.offsetToBase = offsetToBase
  }

  func convertFromBase(_ value: Double) -> Double {
    (value - offsetToBase) / scaleToBase
  }

  func convertToBase(_ value: Double) -> Double {
    value * scaleToBase + offsetToBase
  }
}

private enum CalculatorUnitRegistry {
  private static let unitsByAlias: [String: CalculatorUnit] = {
    var result = [String: CalculatorUnit]()
    for unit in units {
      for alias in unit.aliases {
        result[alias.lowercased()] = unit
      }
    }
    return result
  }()

  private static let units = [
    CalculatorUnit(
      id: "meter",
      dimension: .length,
      symbol: "m",
      aliases: ["m", "meter", "meters", "metre", "metres"],
      scaleToBase: 1
    ),
    CalculatorUnit(
      id: "kilometer",
      dimension: .length,
      symbol: "km",
      aliases: ["km", "kilometer", "kilometers", "kilometre", "kilometres"],
      scaleToBase: 1_000
    ),
    CalculatorUnit(
      id: "centimeter",
      dimension: .length,
      symbol: "cm",
      aliases: ["cm", "centimeter", "centimeters", "centimetre", "centimetres"],
      scaleToBase: 0.01
    ),
    CalculatorUnit(
      id: "millimeter",
      dimension: .length,
      symbol: "mm",
      aliases: ["mm", "millimeter", "millimeters", "millimetre", "millimetres"],
      scaleToBase: 0.001
    ),
    CalculatorUnit(
      id: "inch",
      dimension: .length,
      symbol: "in",
      aliases: ["in", "inch", "inches"],
      scaleToBase: 0.0254
    ),
    CalculatorUnit(
      id: "foot",
      dimension: .length,
      symbol: "ft",
      aliases: ["ft", "foot", "feet"],
      scaleToBase: 0.3048
    ),
    CalculatorUnit(
      id: "yard",
      dimension: .length,
      symbol: "yd",
      aliases: ["yd", "yard", "yards"],
      scaleToBase: 0.9144
    ),
    CalculatorUnit(
      id: "mile",
      dimension: .length,
      symbol: "mi",
      aliases: ["mi", "mile", "miles"],
      scaleToBase: 1_609.344
    ),
    CalculatorUnit(
      id: "kilogram",
      dimension: .mass,
      symbol: "kg",
      aliases: ["kg", "kilogram", "kilograms"],
      scaleToBase: 1
    ),
    CalculatorUnit(
      id: "gram",
      dimension: .mass,
      symbol: "g",
      aliases: ["g", "gram", "grams"],
      scaleToBase: 0.001
    ),
    CalculatorUnit(
      id: "milligram",
      dimension: .mass,
      symbol: "mg",
      aliases: ["mg", "milligram", "milligrams"],
      scaleToBase: 0.000_001
    ),
    CalculatorUnit(
      id: "pound",
      dimension: .mass,
      symbol: "lb",
      aliases: ["lb", "lbs", "pound", "pounds"],
      scaleToBase: 0.453_592_37
    ),
    CalculatorUnit(
      id: "ounce",
      dimension: .mass,
      symbol: "oz",
      aliases: ["oz", "ounce", "ounces"],
      scaleToBase: 0.028_349_523_125
    ),
    CalculatorUnit(
      id: "second",
      dimension: .duration,
      symbol: "s",
      aliases: ["s", "sec", "secs", "second", "seconds"],
      scaleToBase: 1
    ),
    CalculatorUnit(
      id: "minute",
      dimension: .duration,
      symbol: "min",
      aliases: ["min", "mins", "minute", "minutes"],
      scaleToBase: 60
    ),
    CalculatorUnit(
      id: "hour",
      dimension: .duration,
      symbol: "hr",
      aliases: ["h", "hr", "hrs", "hour", "hours"],
      scaleToBase: 3_600
    ),
    CalculatorUnit(
      id: "day",
      dimension: .duration,
      symbol: "day",
      aliases: ["d", "day", "days"],
      scaleToBase: 86_400
    ),
    CalculatorUnit(
      id: "week",
      dimension: .duration,
      symbol: "wk",
      aliases: ["wk", "wks", "week", "weeks"],
      scaleToBase: 604_800
    ),
    CalculatorUnit(
      id: "celsius",
      dimension: .temperature,
      symbol: "°C",
      aliases: ["c", "°c", "celsius"],
      scaleToBase: 1
    ),
    CalculatorUnit(
      id: "fahrenheit",
      dimension: .temperature,
      symbol: "°F",
      aliases: ["f", "°f", "fahrenheit"],
      scaleToBase: 5.0 / 9.0,
      offsetToBase: -160.0 / 9.0
    ),
    CalculatorUnit(
      id: "kelvin",
      dimension: .temperature,
      symbol: "K",
      aliases: ["k", "kelvin"],
      scaleToBase: 1,
      offsetToBase: -273.15
    ),
    CalculatorUnit(
      id: "liter",
      dimension: .volume,
      symbol: "L",
      aliases: ["l", "liter", "liters", "litre", "litres"],
      scaleToBase: 1
    ),
    CalculatorUnit(
      id: "milliliter",
      dimension: .volume,
      symbol: "mL",
      aliases: ["ml", "milliliter", "milliliters", "millilitre", "millilitres"],
      scaleToBase: 0.001
    ),
    CalculatorUnit(
      id: "teaspoon",
      dimension: .volume,
      symbol: "US tsp",
      aliases: ["tsp", "teaspoon", "teaspoons"],
      scaleToBase: 0.004_928_921_593_75
    ),
    CalculatorUnit(
      id: "tablespoon",
      dimension: .volume,
      symbol: "US tbsp",
      aliases: ["tbsp", "tablespoon", "tablespoons"],
      scaleToBase: 0.014_786_764_781_25
    ),
    CalculatorUnit(
      id: "cup",
      dimension: .volume,
      symbol: "US cup",
      aliases: ["cup", "cups"],
      scaleToBase: 0.236_588_236_5
    ),
    CalculatorUnit(
      id: "fluid-ounce",
      dimension: .volume,
      symbol: "US fl oz",
      aliases: ["floz"],
      scaleToBase: 0.029_573_529_562_5
    ),
    CalculatorUnit(
      id: "pint",
      dimension: .volume,
      symbol: "US pt",
      aliases: ["pt", "pint", "pints"],
      scaleToBase: 0.473_176_473
    ),
    CalculatorUnit(
      id: "quart",
      dimension: .volume,
      symbol: "US qt",
      aliases: ["qt", "quart", "quarts"],
      scaleToBase: 0.946_352_946
    ),
    CalculatorUnit(
      id: "gallon",
      dimension: .volume,
      symbol: "US gal",
      aliases: ["gal", "gallon", "gallons"],
      scaleToBase: 3.785_411_784
    ),
    CalculatorUnit(
      id: "byte",
      dimension: .data,
      symbol: "B",
      aliases: ["byte", "bytes"],
      scaleToBase: 1
    ),
    CalculatorUnit(
      id: "bit",
      dimension: .data,
      symbol: "bit",
      aliases: ["bit", "bits"],
      scaleToBase: 0.125
    ),
    CalculatorUnit(
      id: "kilobyte",
      dimension: .data,
      symbol: "kB",
      aliases: ["kb", "kilobyte", "kilobytes"],
      scaleToBase: 1_000
    ),
    CalculatorUnit(
      id: "megabyte",
      dimension: .data,
      symbol: "MB",
      aliases: ["mb", "megabyte", "megabytes"],
      scaleToBase: 1_000_000
    ),
    CalculatorUnit(
      id: "gigabyte",
      dimension: .data,
      symbol: "GB",
      aliases: ["gb", "gigabyte", "gigabytes"],
      scaleToBase: 1_000_000_000
    ),
    CalculatorUnit(
      id: "terabyte",
      dimension: .data,
      symbol: "TB",
      aliases: ["tb", "terabyte", "terabytes"],
      scaleToBase: 1_000_000_000_000
    ),
    CalculatorUnit(
      id: "kibibyte",
      dimension: .data,
      symbol: "KiB",
      aliases: ["kib", "kibibyte", "kibibytes"],
      scaleToBase: 1_024
    ),
    CalculatorUnit(
      id: "mebibyte",
      dimension: .data,
      symbol: "MiB",
      aliases: ["mib", "mebibyte", "mebibytes"],
      scaleToBase: 1_048_576
    ),
    CalculatorUnit(
      id: "gibibyte",
      dimension: .data,
      symbol: "GiB",
      aliases: ["gib", "gibibyte", "gibibytes"],
      scaleToBase: 1_073_741_824
    ),
    CalculatorUnit(
      id: "tebibyte",
      dimension: .data,
      symbol: "TiB",
      aliases: ["tib", "tebibyte", "tebibytes"],
      scaleToBase: 1_099_511_627_776
    ),
  ]

  static func unit(named name: String) -> CalculatorUnit? {
    unitsByAlias[name.lowercased()]
  }
}

private enum CalculatorQuantityToken: Equatable {
  case end
  case minus
  case number(Double)
  case plus
  case word(String)
}

private enum CalculatorQuantityLexer {
  static func tokenize(_ expression: String) -> [CalculatorQuantityToken]? {
    let canonicalExpression =
      expression
      .lowercased()
      .replacingOccurrences(of: "->", with: " to ")
      .replacingOccurrences(of: "→", with: " to ")
    let characters = Array(canonicalExpression)
    var index = 0
    var tokens = [CalculatorQuantityToken]()

    while index < characters.count {
      let character = characters[index]
      if character.isWhitespace {
        index += 1
        continue
      }

      if character.isNumber || character == "." {
        guard let number = number(in: characters, index: &index) else {
          return nil
        }
        tokens.append(.number(number))
        continue
      }

      if character.isLetter || character == "°" {
        let start = index
        while index < characters.count,
          characters[index].isLetter || characters[index] == "°"
        {
          index += 1
        }
        tokens.append(.word(String(characters[start..<index])))
        continue
      }

      switch character {
      case "+": tokens.append(.plus)
      case "-", "−": tokens.append(.minus)
      default: return nil
      }
      index += 1
    }

    tokens.append(.end)
    return tokens
  }

  private static func number(
    in characters: [Character],
    index: inout Int
  ) -> Double? {
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

    if index < characters.count, characters[index] == "e" {
      var exponentEnd = index + 1
      if exponentEnd < characters.count,
        characters[exponentEnd] == "+" || characters[exponentEnd] == "-"
      {
        exponentEnd += 1
      }
      let exponentStart = exponentEnd
      while exponentEnd < characters.count, characters[exponentEnd].isNumber {
        exponentEnd += 1
      }
      if exponentEnd > exponentStart {
        index = exponentEnd
      }
    }

    return Double(String(characters[start..<index]))
  }
}

private struct CalculatorQuantityParser {
  struct Evaluation {
    let value: Double
    let sourceBadge: String?
    let targetUnit: CalculatorUnit
  }

  private struct Component {
    let value: Double
    let unit: CalculatorUnit
  }

  private struct Quantity {
    let baseValue: Double
    let dimension: CalculatorQuantityDimension
    let firstUnit: CalculatorUnit
    let outputUnit: CalculatorUnit
    let componentCount: Int
  }

  private let tokens: [CalculatorQuantityToken]
  private var index = 0

  private var currentToken: CalculatorQuantityToken {
    tokens[index]
  }

  init(tokens: [CalculatorQuantityToken]) {
    self.tokens = tokens
  }

  mutating func parse() -> Evaluation? {
    guard var quantity = parseTerm() else {
      return nil
    }

    var hasArithmetic = false
    while currentToken == .plus || currentToken == .minus {
      let operation = currentToken
      advance()
      guard let right = parseTerm(), right.dimension == quantity.dimension else {
        return nil
      }
      hasArithmetic = true

      if quantity.dimension == .temperature {
        guard quantity.outputUnit.id == right.outputUnit.id,
          right.componentCount == 1
        else {
          return nil
        }
        let leftValue = quantity.outputUnit.convertFromBase(quantity.baseValue)
        let rightValue = right.outputUnit.convertFromBase(right.baseValue)
        let resultValue =
          operation == .plus
          ? leftValue + rightValue
          : leftValue - rightValue
        quantity = Quantity(
          baseValue: quantity.outputUnit.convertToBase(resultValue),
          dimension: quantity.dimension,
          firstUnit: quantity.firstUnit,
          outputUnit: right.outputUnit,
          componentCount: quantity.componentCount + right.componentCount
        )
      } else {
        let resultValue =
          operation == .plus
          ? quantity.baseValue + right.baseValue
          : quantity.baseValue - right.baseValue
        quantity = Quantity(
          baseValue: resultValue,
          dimension: quantity.dimension,
          firstUnit: quantity.firstUnit,
          outputUnit: right.outputUnit,
          componentCount: quantity.componentCount + right.componentCount
        )
      }
    }

    var targetUnit = quantity.outputUnit
    var hasConversion = false
    if isConversionKeyword(currentToken) {
      hasConversion = true
      advance()
      guard case .word(let targetName) = currentToken,
        let parsedTarget = CalculatorUnitRegistry.unit(named: targetName),
        parsedTarget.dimension == quantity.dimension
      else {
        return nil
      }
      targetUnit = parsedTarget
      advance()
    }

    guard currentToken == .end,
      hasConversion || hasArithmetic || quantity.componentCount > 1
    else {
      return nil
    }

    let sourceBadge =
      hasConversion || quantity.firstUnit.id != targetUnit.id
      ? quantity.firstUnit.symbol
      : nil
    return Evaluation(
      value: targetUnit.convertFromBase(quantity.baseValue),
      sourceBadge: sourceBadge,
      targetUnit: targetUnit
    )
  }

  private mutating func parseTerm() -> Quantity? {
    guard let firstComponent = parseComponent() else {
      return nil
    }

    var baseValue = firstComponent.unit.convertToBase(firstComponent.value)
    var componentCount = 1
    while case .number = currentToken {
      guard let component = parseComponent(),
        component.unit.dimension == firstComponent.unit.dimension,
        component.unit.dimension != .temperature
      else {
        return nil
      }
      baseValue += component.unit.convertToBase(component.value)
      componentCount += 1
    }

    return Quantity(
      baseValue: baseValue,
      dimension: firstComponent.unit.dimension,
      firstUnit: firstComponent.unit,
      outputUnit: firstComponent.unit,
      componentCount: componentCount
    )
  }

  private mutating func parseComponent() -> Component? {
    var sign = 1.0
    if currentToken == .plus {
      advance()
    } else if currentToken == .minus {
      sign = -1
      advance()
    }

    guard case .number(let value) = currentToken else {
      return nil
    }
    advance()
    guard case .word(let unitName) = currentToken,
      let unit = CalculatorUnitRegistry.unit(named: unitName)
    else {
      return nil
    }
    advance()
    return Component(value: sign * value, unit: unit)
  }

  private func isConversionKeyword(_ token: CalculatorQuantityToken) -> Bool {
    token == .word("to") || token == .word("in")
  }

  private mutating func advance() {
    index += 1
  }
}
