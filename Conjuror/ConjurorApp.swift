import AppKit
import SwiftUI

@main
struct ConjurorApp: App {
    @NSApplicationDelegateAdaptor(AppController.self) private var appController

    var body: some Scene {
        Window("Conjuror", id: "launcher") {
            ContentView(
                store: appController.store,
                hotKeyErrorMessage: appController.hotKeyErrorMessage,
                onWindowAvailable: appController.register,
                onHide: appController.hideLauncher,
                onQuit: { NSApp.terminate(nil) }
            )
        }
        .defaultSize(width: 620, height: 400)
        .windowResizability(.contentSize)
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}
