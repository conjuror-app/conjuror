struct CalculatorResult: Equatable, Sendable {
  let expression: String
  let display: String
  let copyText: String
  let sourceDisplay: String?
  let sourceBadge: String?
  let targetBadge: String?

  init(
    expression: String,
    display: String,
    copyText: String,
    sourceDisplay: String? = nil,
    sourceBadge: String? = nil,
    targetBadge: String? = nil
  ) {
    self.expression = expression
    self.display = display
    self.copyText = copyText
    self.sourceDisplay = sourceDisplay
    self.sourceBadge = sourceBadge
    self.targetBadge = targetBadge
  }
}
