import AppIntents
import AppKit

@main
enum ConjurorApp {
  @MainActor
  static func main() {
    let application = NSApplication.shared
    let appController = AppController()
    application.delegate = appController
    withExtendedLifetime(appController) {
      application.run()
    }
  }
}
