import AppKit
import SwiftUI

@main
struct ConjurorApp: App {
    @StateObject private var store = LauncherStore(onLaunchSuccess: {
        NSApp.hide(nil)
    })

    var body: some Scene {
        WindowGroup("Conjuror") {
            ContentView(
                store: store,
                onQuit: { NSApp.terminate(nil) }
            )
        }
        .defaultSize(width: 720, height: 470)
        .windowResizability(.contentSize)
        .windowStyle(.hiddenTitleBar)
    }
}
