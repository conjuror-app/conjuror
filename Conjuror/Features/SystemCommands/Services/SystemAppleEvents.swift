import CoreServices
import Foundation

/// Sends Apple events to system processes without compiling AppleScript.
enum SystemAppleEvents {
  /// The target app named in permission errors.
  struct Target: Sendable {
    static let finder = Target(bundleIdentifier: "com.apple.finder", name: "Finder")
    static let loginWindow = Target(bundleIdentifier: "com.apple.loginwindow", name: "loginwindow")
    static let systemEvents = Target(
      bundleIdentifier: "com.apple.systemevents",
      name: "System Events"
    )

    let bundleIdentifier: String
    let name: String
  }

  private static let permissionErrorCodes: Set<Int> = [
    Int(errAEEventNotPermitted),
    Int(errAEEventWouldRequireUserConsent),
    -10004,  // errAEPrivilegeError
  ]

  static func send(
    eventClass: AEEventClass,
    eventID: AEEventID,
    to target: Target,
    timeout: TimeInterval = 30
  ) throws {
    let event = NSAppleEventDescriptor(
      eventClass: eventClass,
      eventID: eventID,
      targetDescriptor: NSAppleEventDescriptor(bundleIdentifier: target.bundleIdentifier),
      returnID: AEReturnID(kAutoGenerateReturnID),
      transactionID: AETransactionID(kAnyTransactionID)
    )

    let reply: NSAppleEventDescriptor

    do {
      reply = try event.sendEvent(options: [.waitForReply, .canInteract], timeout: timeout)
    } catch let error as NSError {
      throw self.error(code: error.code, target: target)
    }

    if let code = reply.paramDescriptor(forKeyword: keyErrorNumber)?.int32Value, code != noErr {
      throw self.error(code: Int(code), target: target)
    }
  }

  /// Runs AppleScript source for scripting-only operations with no equivalent raw event.
  static func run(script source: String, target: Target) throws {
    guard let script = NSAppleScript(source: source) else {
      throw SystemCommandError.failed(code: nil)
    }

    var errorInfo: NSDictionary?
    script.executeAndReturnError(&errorInfo)

    if let errorInfo {
      throw error(code: errorInfo[NSAppleScript.errorNumber] as? Int, target: target)
    }
  }

  static func error(code: Int?, target: Target) -> SystemCommandError {
    guard let code, permissionErrorCodes.contains(code) else {
      return .failed(code: code)
    }

    return .permissionDenied(appName: target.name)
  }
}
