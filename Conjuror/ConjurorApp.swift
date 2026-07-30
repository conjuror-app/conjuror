import SwiftUI

@main
struct ConjurorApp: App {
    var body: some Scene {
        WindowGroup("Conjuror") {
            ContentView()
        }
        .defaultSize(width: 720, height: 470)
        .windowResizability(.contentSize)
        .windowStyle(.hiddenTitleBar)
    }
}
