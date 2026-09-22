import Foundation
import Testing

@testable import Conjuror

extension CalculatorEngineTests {
  @Test("Integer radix conversions are evaluated")
  func testIntegerRadixConversions() {
    #expect(evaluate("255 to hex") == "0xFF")
    #expect(evaluate("255 in octal") == "0o377")
    #expect(evaluate("255 -> binary") == "0b11111111")
    #expect(evaluate("0b11111111 → decimal") == "255")
    #expect(evaluate("0o377 to hex") == "0xFF")
    #expect(evaluate("0xFF to oct") == "0o377")
    #expect(evaluate("42 to hexadecimal") == "0x2A")
    #expect(evaluate("42 to bin") == "0b101010")
  }

  @Test("Prefixed integers automatically convert to decimal")
  func testRadixPrefixes() {
    #expect(evaluate("0xFF") == "255")
    #expect(evaluate("0Xff") == "255")
    #expect(evaluate("0o52") == "42")
    #expect(evaluate("0b101010") == "42")
  }

  @Test("Negative radix conversions use sign-magnitude notation")
  func testNegativeRadixConversions() {
    #expect(evaluate("-42 to hex") == "-0x2A")
    #expect(evaluate("-42 to octal") == "-0o52")
    #expect(evaluate("-0x2A to decimal") == "-42")
    #expect(evaluate("-0o52 to binary") == "-0b101010")
    #expect(evaluate("-0b101010") == "-42")
  }

  @Test("Radix conversion handles integer boundaries")
  func testRadixBoundaries() {
    #expect(evaluate("0 to hex") == "0x0")
    #expect(evaluate("9223372036854775807 to hex") == "0x7FFFFFFFFFFFFFFF")
    #expect(evaluate("-0x8000000000000000 to decimal") == "-9223372036854775808")
  }

  @Test("Invalid radix input stays silent")
  func testInvalidRadixInputStaysSilent() {
    #expect(engine.evaluate("42 to decimal") == nil)
    #expect(engine.evaluate("1.5 to hex") == nil)
    #expect(engine.evaluate("0x to decimal") == nil)
    #expect(engine.evaluate("0xGG to decimal") == nil)
    #expect(engine.evaluate("0o8 to decimal") == nil)
    #expect(engine.evaluate("0b2 to decimal") == nil)
    #expect(engine.evaluate("0xFF to") == nil)
    #expect(engine.evaluate("0x8000000000000000 to decimal") == nil)
    #expect(engine.evaluate("9223372036854775808 to hex") == nil)
  }
}
