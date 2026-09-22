import Foundation

struct CalculatorQuantityParser {
  struct Evaluation {
    let value: Double
    let sourceValue: Double
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
    } else if !hasArithmetic, quantity.componentCount == 1 {
      guard let defaultTarget = CalculatorUnitRegistry.defaultTarget(for: quantity.firstUnit)
      else {
        return nil
      }

      targetUnit = defaultTarget
    }

    guard currentToken == .end else {
      return nil
    }

    let sourceBadge =
      hasConversion || quantity.firstUnit.id != targetUnit.id
      ? quantity.firstUnit.symbol
      : nil
    return Evaluation(
      value: targetUnit.convertFromBase(quantity.baseValue),
      sourceValue: quantity.firstUnit.convertFromBase(quantity.baseValue),
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

enum CalculatorQuantityToken: Equatable {
  case end
  case minus
  case number(Double)
  case plus
  case word(String)
}

enum CalculatorQuantityLexer {
  static func tokenize(_ expression: String) -> [CalculatorQuantityToken]? {
    let canonicalExpression = CalculatorInput.normalizeConversion(
      expression,
      lowercased: true
    )
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
        guard
          case .number(let number, _) = CalculatorLexer.numberToken(
            in: characters,
            index: &index
          )
        else {
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
}
