import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            Image(systemName: "sparkles")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Hello, Conjuror!")
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
