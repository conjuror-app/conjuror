import XCTest

@testable import Conjuror

final class CalculatorQuantityTests: XCTestCase {
  private let engine = CalculatorEngine(
    formattingOptions: CalculatorFormattingOptions(
      localeIdentifier: "en_US_POSIX",
      maximumSignificantDigits: 10
    )
  )

  func testExplicitConversionsAcrossSupportedDimensions() {
    XCTAssertEqual(evaluate("10 km to miles"), "6.213711922 mi")
    XCTAssertEqual(evaluate("1 lb to kg"), "0.45359237 kg")
    XCTAssertEqual(evaluate("2 hours to minutes"), "120 min")
    XCTAssertEqual(evaluate("30 °C to °F"), "86 °F")
    XCTAssertEqual(evaluate("-40 c to f"), "-40 °F")
    XCTAssertEqual(evaluate("1 L to mL"), "1000 mL")
    XCTAssertEqual(evaluate("1 GiB to MiB"), "1024 MiB")
  }

  func testConversionAcceptsInAndArrowSeparators() {
    XCTAssertEqual(evaluate("12 in in cm"), "30.48 cm")
    XCTAssertEqual(evaluate("1 gallon -> liters"), "3.785411784 L")
    XCTAssertEqual(evaluate("8 bits → bytes"), "1 B")
  }

  func testBareQuantitiesUseSensibleDefaultConversions() {
    XCTAssertEqual(evaluate("100 lbs"), "45.359237 kg")
    XCTAssertEqual(evaluate("1 cm"), "0.3937007874 in")
    XCTAssertEqual(evaluate("1 inch"), "2.54 cm")
    XCTAssertEqual(evaluate("1 km"), "0.6213711922 mi")
    XCTAssertEqual(evaluate("1 mile"), "1.609344 km")
    XCTAssertEqual(evaluate("90 minutes"), "1.5 hr")
    XCTAssertEqual(evaluate("30 c"), "86 °F")
    XCTAssertEqual(evaluate("1 GiB"), "1.073741824 GB")
  }

  func testEveryUnitHasADefaultConversion() {
    let expectedTargets = [
      ("m", "ft"), ("km", "mi"), ("cm", "in"), ("mm", "in"),
      ("inch", "cm"), ("foot", "m"), ("yard", "m"), ("mile", "km"),
      ("kg", "lb"), ("g", "oz"), ("mg", "g"), ("lb", "kg"), ("oz", "g"),
      ("second", "min"), ("minute", "hr"), ("hour", "min"), ("day", "hr"),
      ("week", "day"),
      ("celsius", "°F"), ("fahrenheit", "°C"), ("kelvin", "°C"),
      ("liter", "US gal"), ("ml", "US fl oz"), ("tsp", "mL"),
      ("tbsp", "mL"), ("cup", "mL"), ("floz", "mL"), ("pint", "L"),
      ("quart", "L"), ("gallon", "L"),
      ("byte", "bit"), ("bit", "B"), ("kb", "KiB"), ("mb", "MiB"),
      ("gb", "GiB"), ("tb", "TiB"), ("kib", "kB"), ("mib", "MB"),
      ("gib", "GB"), ("tib", "TB"),
    ]

    for (source, target) in expectedTargets {
      XCTAssertEqual(engine.evaluate("1 \(source)")?.targetBadge, target, source)
    }
  }

  func testTypedArithmeticUsesLastWrittenUnit() {
    XCTAssertEqual(evaluate("10kg + 500g"), "10500 g")
    XCTAssertEqual(evaluate("2 hours - 30 minutes"), "90 min")
    XCTAssertEqual(evaluate("5 feet + 1m"), "2.524 m")
    XCTAssertEqual(evaluate("1hr + 30min to s"), "5400 s")
  }

  func testCompositeQuantitiesUseLeadingUnit() {
    XCTAssertEqual(evaluate("5 ft 3 in"), "5.25 ft")
    XCTAssertEqual(evaluate("1hr30min"), "1.5 hr")
    XCTAssertEqual(evaluate("5ft 3in to cm"), "160.02 cm")
  }

  func testTemperatureArithmeticRequiresMatchingScales() {
    XCTAssertEqual(evaluate("10 c + 5 c"), "15 °C")
    XCTAssertNil(engine.evaluate("10 c + 50 f"))
  }

  func testInvalidAndIncompatibleQuantitiesStaySilent() {
    XCTAssertNil(engine.evaluate("10 unknown"))
    XCTAssertNil(engine.evaluate("1 kg + 1 m"))
    XCTAssertNil(engine.evaluate("5 ft 3 kg"))
    XCTAssertNil(engine.evaluate("10 km to kg"))
  }

  func testQuantityResultCarriesSummarizedSourceAndUnitBadges() {
    let result = engine.evaluate("1 cm in in")

    XCTAssertEqual(result?.sourceDisplay, "1")
    XCTAssertEqual(result?.sourceBadge, "cm")
    XCTAssertEqual(result?.display, "0.3937007874")
    XCTAssertEqual(result?.targetBadge, "in")
  }

  private func evaluate(_ expression: String) -> String? {
    engine.evaluate(expression)?.copyText
  }
}
