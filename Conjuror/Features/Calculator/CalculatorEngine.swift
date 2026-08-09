import Foundation

struct CalculatorEngine: CalculatorEvaluating {
    private let formattingOptions: CalculatorFormattingOptions

    init(formattingOptions: CalculatorFormattingOptions = .compact) {
        self.formattingOptions = formattingOptions
    }

    func evaluate(_ expression: String) -> CalculatorResult? {
        let trimmedExpression = expression.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedExpression.isEmpty else {
            return nil
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

struct CalculatorResult: Equatable, Sendable {
    let expression: String
    let display: String
    let copyText: String
    let sourceBadge: String?
    let targetBadge: String?

    init(
        expression: String,
        display: String,
        copyText: String,
        sourceBadge: String? = nil,
        targetBadge: String? = nil
    ) {
        self.expression = expression
        self.display = display
        self.copyText = copyText
        self.sourceBadge = sourceBadge
        self.targetBadge = targetBadge
    }
}

struct CalculatorFormattingOptions: Equatable, Sendable {
    static let compact = CalculatorFormattingOptions()

    let localeIdentifier: String
    let maximumFractionDigits: Int

    init(
        localeIdentifier: String = Locale.current.identifier,
        maximumFractionDigits: Int = 10
    ) {
        self.localeIdentifier = localeIdentifier
        self.maximumFractionDigits = maximumFractionDigits
    }
}

protocol CalculatorEvaluating {
    func evaluate(_ expression: String) -> CalculatorResult?
}

struct CalculatorNumberFormatter {
    let options: CalculatorFormattingOptions

    func string(
        from value: Double,
        usesGroupingSeparator: Bool
    ) -> String? {
        let normalizedValue = value == 0 ? 0 : value
        let magnitude = Swift.abs(normalizedValue)
        if magnitude != 0,
           magnitude < Foundation.pow(10, Double(-options.maximumFractionDigits))
            || magnitude >= 1e15
        {
            return String(
                format: "%.*g",
                locale: Locale(identifier: options.localeIdentifier),
                options.maximumFractionDigits,
                normalizedValue
            )
        }

        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: options.localeIdentifier)
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = options.maximumFractionDigits
        formatter.usesGroupingSeparator = usesGroupingSeparator
        return formatter.string(from: NSNumber(value: normalizedValue))
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
        let canonicalExpression = expression
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
                let number = operation == .plus
                    ? left.number + right.number
                    : left.number - right.number
                left = ParsedValue(number: number, isPercent: true)
            } else {
                let rightNumber = right.isPercent
                    ? left.number * right.number
                    : right.number
                let number = operation == .plus
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
