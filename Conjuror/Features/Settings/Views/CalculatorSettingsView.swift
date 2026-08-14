import SwiftUI

struct CalculatorSettingsView: View {
  @ObservedObject var currencyRateStore: CurrencyRateStore

  var body: some View {
    SettingsPane {
      SettingsRow(
        title: "Currency conversion",
        description: "Download daily exchange rates from Frankfurter. No search text is sent."
      ) {
        Toggle(
          "Currency conversion",
          isOn: Binding(
            get: { currencyRateStore.isEnabled },
            set: { isEnabled in
              currencyRateStore.setEnabled(isEnabled)
            }
          )
        )
        .labelsHidden()
      }

      Spacer()
    }
  }
}
