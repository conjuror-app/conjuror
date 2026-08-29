import AppIntents
import AppKit
import Darwin

@main
enum ConjurorApp {
  @MainActor
  static func main() {
    if let status = ShortcutCatalogProcess.runHelperIfRequested() {
      Darwin.exit(status)
    }

    let application = NSApplication.shared
    let appController = AppController()
    application.delegate = appController
    withExtendedLifetime(appController) {
      application.run()
    }
  }
}
