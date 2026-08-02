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
        .defaultSize(width: 720, height: 470)
        .windowResizability(.contentSize)
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}
