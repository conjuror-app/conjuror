import SwiftUI

struct CalculatorSettingsView: View {
  var body: some View {
    SettingsPane {
      SettingsRow(
        title: "Calculation engine",
        description: "Natural-language calculations are evaluated locally by SoulverCore."
      ) {
        Text("SoulverCore")
          .foregroundStyle(.secondary)
      }

      SettingsRow(
        title: "Currency rates",
        description:
          "SoulverCore downloads current fiat currency rates from the European Central Bank."
      ) {
        Text("ECB")
          .foregroundStyle(.secondary)
      }

      Spacer()
    }
  }
}
