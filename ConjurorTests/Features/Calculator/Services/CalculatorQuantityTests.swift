import Testing

@testable import Conjuror

@Suite("Calculator Quantity")
struct CalculatorQuantityTests {
  private let engine = CalculatorEngine(
    formattingOptions: CalculatorFormattingOptions(
      localeIdentifier: "en_US_POSIX",
      maximumSignificantDigits: 10
    )
  )

  @Test("Calculator quantity: explicit conversions work across supported dimensions")
  func testExplicitConversionsAcrossSupportedDimensions() {
    #expect(evaluate("10 km to miles") == "6.213711922 mi")
    #expect(evaluate("1 lb to kg") == "0.45359237 kg")
    #expect(evaluate("2 hours to minutes") == "120 min")
    #expect(evaluate("30 °C to °F") == "86 °F")
    #expect(evaluate("-40 c to f") == "-40 °F")
    #expect(evaluate("1 L to mL") == "1000 mL")
    #expect(evaluate("1 GiB to MiB") == "1024 MiB")
    #expect(evaluate("1e3 m to km") == "1 km")
    #expect(evaluate("1e-3 kg to g") == "1 g")
    #expect(evaluate("1e+3 g to kg") == "1 kg")
  }

  @Test("Calculator quantity: in and arrow separators are accepted")
  func testConversionAcceptsInAndArrowSeparators() {
    #expect(evaluate("12 in in cm") == "30.48 cm")
    #expect(evaluate("1 gallon -> liters") == "3.785411784 L")
    #expect(evaluate("8 bits → bytes") == "1 B")
  }

  @Test("Calculator quantity: locale grouping separators are not duplicated")
  func testConversionDoesNotDuplicateLocaleGroupingSeparator() {
    let localeEngine = CalculatorEngine(
      formattingOptions: CalculatorFormattingOptions(localeIdentifier: "en_US")
    )

    let result = localeEngine.evaluate("1 gb in mb")

    #expect(result?.display == "1,000")
    #expect(result?.copyText == "1000 MB")
  }

  @Test("Calculator quantity: bare quantities use sensible default conversions")
  func testBareQuantitiesUseSensibleDefaultConversions() {
    let expectations = [
      ("1 kg", "2.204622622 lb", "kg", "lb"),
      ("1 g", "0.03527396195 oz", "g", "oz"),
      ("1 mg", "0.001 g", "mg", "g"),
      ("100 lbs", "45.359237 kg", "lb", "kg"),
      ("1 oz", "28.34952312 g", "oz", "g"),
      ("1 cm", "0.3937007874 in", "cm", "in"),
      ("1 inch", "2.54 cm", "in", "cm"),
      ("1 km", "0.6213711922 mi", "km", "mi"),
      ("1 mile", "1.609344 km", "mi", "km"),
      ("1 s", "0.01666666667 min", "s", "min"),
      ("90 minutes", "1.5 hr", "min", "hr"),
      ("1 hr", "60 min", "hr", "min"),
      ("1 day", "24 hr", "day", "hr"),
      ("1 wk", "7 day", "wk", "day"),
      ("30 c", "86 °F", "°C", "°F"),
      ("1 f", "-17.22222222 °C", "°F", "°C"),
      ("1 k", "-272.15 °C", "K", "°C"),
      ("1 L", "0.2641720524 US gal", "L", "US gal"),
      ("1 mL", "0.0338140227 US fl oz", "mL", "US fl oz"),
      ("1 tsp", "4.928921594 mL", "US tsp", "mL"),
      ("1 tbsp", "14.78676478 mL", "US tbsp", "mL"),
      ("1 cup", "236.5882365 mL", "US cup", "mL"),
      ("1 floz", "29.57352956 mL", "US fl oz", "mL"),
      ("1 pint", "0.473176473 L", "US pt", "L"),
      ("1 quart", "0.946352946 L", "US qt", "L"),
      ("1 gallon", "3.785411784 L", "US gal", "L"),
      ("1 byte", "8 bit", "B", "bit"),
      ("1 bit", "0.125 B", "bit", "B"),
      ("1 kb", "0.9765625 KiB", "kB", "KiB"),
      ("1 mb", "0.9536743164 MiB", "MB", "MiB"),
      ("1 gb", "0.9313225746 GiB", "GB", "GiB"),
      ("1 tb", "0.9094947018 TiB", "TB", "TiB"),
      ("1 kib", "1.024 kB", "KiB", "kB"),
      ("1 mib", "1.048576 MB", "MiB", "MB"),
      ("1 GiB", "1.073741824 GB", "GiB", "GB"),
      ("1 tib", "1.099511628 TB", "TiB", "TB"),
    ]

    for (expression, copyText, sourceBadge, targetBadge) in expectations {
      let result = engine.evaluate(expression)

      #expect(result?.copyText == copyText, Comment(rawValue: expression))
      #expect(result?.sourceBadge == sourceBadge, Comment(rawValue: expression))
      #expect(result?.targetBadge == targetBadge, Comment(rawValue: expression))
    }
  }

  @Test("Calculator quantity: every unit has a default conversion")
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
      #expect(engine.evaluate("1 \(source)")?.targetBadge == target, Comment(rawValue: source))
    }
  }

  @Test("Calculator quantity: typed arithmetic uses the last written unit")
  func testTypedArithmeticUsesLastWrittenUnit() {
    #expect(evaluate("10kg + 500g") == "10500 g")
    #expect(evaluate("2 hours - 30 minutes") == "90 min")
    #expect(evaluate("5 feet + 1m") == "2.524 m")
    #expect(evaluate("1hr + 30min to s") == "5400 s")
  }

  @Test("Calculator quantity: composite quantities use the leading unit")
  func testCompositeQuantitiesUseLeadingUnit() {
    #expect(evaluate("5 ft 3 in") == "5.25 ft")
    #expect(evaluate("1hr30min") == "1.5 hr")
    #expect(evaluate("5ft 3in to cm") == "160.02 cm")
  }

  @Test("Calculator quantity: temperature arithmetic requires matching scales")
  func testTemperatureArithmeticRequiresMatchingScales() {
    #expect(evaluate("10 c + 5 c") == "15 °C")
    #expect((engine.evaluate("10 c + 50 f")) == nil)
  }

  @Test("Calculator quantity: invalid and incompatible quantities stay silent")
  func testInvalidAndIncompatibleQuantitiesStaySilent() {
    #expect((engine.evaluate("10 unknown")) == nil)
    #expect((engine.evaluate("1 kg + 1 m")) == nil)
    #expect((engine.evaluate("5 ft 3 kg")) == nil)
    #expect((engine.evaluate("10 km to kg")) == nil)
    #expect(engine.evaluate("1e kg to g") == nil)
    #expect(engine.evaluate("1e400 kg to g") == nil)
  }

  @Test("Calculator quantity: results carry summarized source and unit badges")
  func testQuantityResultCarriesSummarizedSourceAndUnitBadges() {
    let result = engine.evaluate("1 cm in in")

    #expect(result?.sourceDisplay == "1")
    #expect(result?.sourceBadge == "cm")
    #expect(result?.display == "0.3937007874")
    #expect(result?.targetBadge == "in")
  }

  private func evaluate(_ expression: String) -> String? {
    engine.evaluate(expression)?.copyText
  }
}
