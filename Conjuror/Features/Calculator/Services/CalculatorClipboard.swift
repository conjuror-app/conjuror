import AppKit

@MainActor
protocol CalculatorClipboardWriting {
  func write(_ text: String)
}

@MainActor
struct SystemCalculatorClipboard: CalculatorClipboardWriting {
  func write(_ text: String) {
    let pasteboard = NSPasteboard.general
    pasteboard.clearContents()
    pasteboard.setString(text, forType: .string)
  }
}
