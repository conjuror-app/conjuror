import AppKit
import CoreServices
import Darwin
import IOKit.pwr_mgt

@MainActor
struct SystemCommandRunner {
  /// A mounted volume's resource values, separated so ejection can be tested without disks.
  struct Volume: Equatable, Sendable {
    let url: URL
    let isEjectable: Bool
    let isRemovable: Bool
    let isRootFileSystem: Bool
  }

  /// Finder's `fndr` event class, which the SDK headers do not define.
  private nonisolated static let finderSuite: AEEventClass = 0x666E_6472

  private nonisolated static let volumeKeys: [URLResourceKey] = [
    .volumeIsEjectableKey,
    .volumeIsRemovableKey,
    .volumeIsRootFileSystemKey,
  ]

  /// The volumes Eject All Disks unmounts: removable or ejectable volumes other than the startup
  /// disk.
  nonisolated static func ejectableVolumes(from volumes: [Volume]) -> [URL] {
    volumes
      .filter { ($0.isEjectable || $0.isRemovable) && !$0.isRootFileSystem }
      .map(\.url)
  }

  private nonisolated static func mountedVolumes() -> [Volume] {
    let urls =
      FileManager.default.mountedVolumeURLs(
        includingResourceValuesForKeys: volumeKeys,
        options: .skipHiddenVolumes
      ) ?? []

    return urls.compactMap { url in
      guard let values = try? url.resourceValues(forKeys: Set(volumeKeys)) else { return nil }

      return Volume(
        url: url,
        isEjectable: values.volumeIsEjectable ?? false,
        isRemovable: values.volumeIsRemovable ?? false,
        isRootFileSystem: values.volumeIsRootFileSystem ?? false
      )
    }
  }

  private nonisolated static func ejectAllDisks() throws {
    let urls = ejectableVolumes(from: mountedVolumes())

    guard !urls.isEmpty else { throw SystemCommandError.noEjectableVolumes }

    let failedNames = urls.compactMap { url -> String? in
      do {
        try NSWorkspace.shared.unmountAndEjectDevice(at: url)

        return nil
      } catch {
        return FileManager.default.displayName(atPath: url.path)
      }
    }

    if !failedNames.isEmpty {
      throw SystemCommandError.volumesNotEjected(names: failedNames)
    }
  }

  private nonisolated static func sleepDisplays() throws {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
    process.arguments = ["displaysleepnow"]
    try process.run()
    process.waitUntilExit()

    guard process.terminationStatus == 0 else {
      throw SystemCommandError.failed(code: Int(process.terminationStatus))
    }
  }

  func run(_ command: SystemCommand) async throws {
    switch command {
    case .lockScreen:
      try lockScreen()
    case .sleep:
      try sleep()
    case .sleepDisplays:
      try await detached(Self.sleepDisplays)
    case .startScreenSaver:
      try await startScreenSaver()
    case .showDesktop:
      try showDesktop()
    case .toggleDarkMode:
      try await detached {
        try SystemAppleEvents.run(
          script: """
            tell application id "com.apple.systemevents"
                tell appearance preferences to set dark mode to not dark mode
            end tell
            """,
          target: .systemEvents
        )
      }
    case .ejectAllDisks:
      try await detached(Self.ejectAllDisks)
    case .emptyTrash:
      try await detached {
        // Finder replies when it finishes, which can take a while for a large Trash.
        try SystemAppleEvents.send(
          eventClass: Self.finderSuite,
          eventID: AEEventID(kAEEmptyTrash),
          to: .finder,
          timeout: 600
        )
      }
    case .logOut:
      try await sendLoginWindowEvent(AEEventID(kAELogOut))
    case .restart:
      try await sendLoginWindowEvent(AEEventID(kAEShowRestartDialog))
    case .shutDown:
      try await sendLoginWindowEvent(AEEventID(kAEShowShutdownDialog))
    }
  }

  private func detached(_ operation: @escaping @Sendable () throws -> Void) async throws {
    try await Task.detached(priority: .userInitiated, operation: operation).value
  }

  /// Asks loginwindow to show its own confirmation dialog, which can be cancelled.
  private func sendLoginWindowEvent(_ eventID: AEEventID) async throws {
    try await detached {
      try SystemAppleEvents.send(
        eventClass: AEEventClass(kCoreEventClass),
        eventID: eventID,
        to: .loginWindow
      )
    }
  }

  private func lockScreen() throws {
    typealias LockScreen = @convention(c) () -> Int32

    guard
      let handle = dlopen(
        "/System/Library/PrivateFrameworks/login.framework/Versions/Current/login",
        RTLD_LAZY
      ),
      let symbol = dlsym(handle, "SACLockScreenImmediate")
    else {
      throw SystemCommandError.unavailable
    }

    let result = unsafeBitCast(symbol, to: LockScreen.self)()

    guard result == 0 else { throw SystemCommandError.failed(code: Int(result)) }
  }

  private func sleep() throws {
    let powerManagement = IOPMFindPowerManagement(kIOMainPortDefault)

    guard powerManagement != MACH_PORT_NULL else { throw SystemCommandError.unavailable }

    defer { IOServiceClose(powerManagement) }

    let result = IOPMSleepSystem(powerManagement)

    guard result == kIOReturnSuccess else { throw SystemCommandError.failed(code: Int(result)) }
  }

  private func startScreenSaver() async throws {
    let url = URL(fileURLWithPath: "/System/Library/CoreServices/ScreenSaverEngine.app")

    try await NSWorkspace.shared.openApplication(
      at: url,
      configuration: NSWorkspace.OpenConfiguration()
    )
  }

  private func showDesktop() throws {
    typealias SendNotification = @convention(c) (CFString, UnsafeMutableRawPointer?) -> Void

    // AppKit loads HIServices, which exports the Dock notification function.
    guard let symbol = dlsym(dlopen(nil, RTLD_NOW), "CoreDockSendNotification") else {
      throw SystemCommandError.unavailable
    }

    unsafeBitCast(symbol, to: SendNotification.self)("com.apple.showdesktop.awake" as CFString, nil)
  }
}

enum SystemCommandError: LocalizedError, Equatable {
  case failed(code: Int?)
  case noEjectableVolumes
  case permissionDenied(appName: String)
  case unavailable
  case volumesNotEjected(names: [String])

  var errorDescription: String? {
    switch self {
    case .failed(let code?):
      "macOS returned error \(code)."
    case .failed(nil):
      "macOS returned an unknown error."
    case .noEjectableVolumes:
      "There are no disks to eject."
    case .permissionDenied(let appName):
      "Allow Conjuror to control \(appName) in System Settings › Privacy & Security › Automation."
    case .unavailable:
      "This command isn’t available on this version of macOS."
    case .volumesNotEjected(let names):
      "\(names.formatted(.list(type: .and))) could not be ejected."
    }
  }
}
