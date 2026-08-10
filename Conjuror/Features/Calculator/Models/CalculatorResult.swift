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
