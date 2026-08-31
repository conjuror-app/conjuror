struct CalculatorResult: Equatable, Sendable {
  let expression: String
  let display: String
  let copyText: String

  init(
    expression: String,
    display: String,
    copyText: String
  ) {
    self.expression = expression
    self.display = display
    self.copyText = copyText
  }
}
