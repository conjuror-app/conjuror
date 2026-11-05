import AppKit

@MainActor
struct WorkspaceRunningApplicationController: RunningApplicationControlling {
  private static let relaunchTimeout = Duration.seconds(30)

  func candidates() -> [RunningApplicationCandidate] {
    NSWorkspace.shared.runningApplications.map(RunningApplicationCandidate.init)
  }

  func observeChanges(_ onChange: @escaping @MainActor @Sendable () -> Void) -> AnyObject {
    WorkspaceApplicationObservation(onChange: onChange)
  }

  func activate(_ application: RunningApplication) throws {
    let runningApplication = try running(application)

    if runningApplication.isHidden { runningApplication.unhide() }

    guard runningApplication.activate(from: .current) else {
      throw RunningApplicationActionError.notActivated
    }
  }

  func hide(_ application: RunningApplication) throws {
    guard try running(application).hide() else {
      throw RunningApplicationActionError.notHidden
    }
  }

  func hideOthers(except application: RunningApplication) throws {
    let target = try running(application)

    for other in NSWorkspace.shared.runningApplications
    where other.activationPolicy == .regular && other != target && other != .current {
      other.hide()
    }

    try activate(application)
  }

  func quit(_ application: RunningApplication) throws {
    guard try running(application).terminate() else {
      throw RunningApplicationActionError.notQuit
    }
  }

  func forceQuit(_ application: RunningApplication) throws {
    guard try running(application).forceTerminate() else {
      throw RunningApplicationActionError.notQuit
    }
  }

  func relaunch(_ application: RunningApplication) async throws {
    guard let bundleURL = application.bundleURL else {
      throw RunningApplicationActionError.noBundle
    }

    try await terminateAndWait(try running(application))

    let configuration = NSWorkspace.OpenConfiguration()
    configuration.activates = true
    _ = try await NSWorkspace.shared.openApplication(at: bundleURL, configuration: configuration)
  }

  private func running(_ application: RunningApplication) throws -> NSRunningApplication {
    guard
      let runningApplication = NSRunningApplication(
        processIdentifier: application.processIdentifier
      ),
      !runningApplication.isTerminated
    else {
      throw RunningApplicationActionError.notRunning
    }

    return runningApplication
  }

  /// Quits the app and waits for its termination notification. The app may cancel quitting, such
  /// as from a save prompt, so the wait gives up after a timeout.
  private func terminateAndWait(_ application: NSRunningApplication) async throws {
    let processIdentifier = application.processIdentifier
    let notificationCenter = NSWorkspace.shared.notificationCenter
    let resumer = ContinuationResumer()
    let observer = notificationCenter.addObserver(
      forName: NSWorkspace.didTerminateApplicationNotification,
      object: nil,
      queue: .main
    ) { notification in
      let terminated =
        notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication

      if terminated?.processIdentifier == processIdentifier { resumer.resume() }
    }
    defer { notificationCenter.removeObserver(observer) }

    let timeout = Task {
      try await Task.sleep(for: Self.relaunchTimeout)
      resumer.resume(throwing: RunningApplicationActionError.didNotQuit)
    }
    defer { timeout.cancel() }

    try await withCheckedThrowingContinuation { continuation in
      resumer.start(continuation)

      if !application.terminate() {
        resumer.resume(throwing: RunningApplicationActionError.notQuit)
      }
    }
  }
}

@MainActor
protocol RunningApplicationControlling {
  func candidates() -> [RunningApplicationCandidate]
  /// Calls `onChange` when apps launch, quit, hide, or unhide, until the returned token is released.
  func observeChanges(_ onChange: @escaping @MainActor @Sendable () -> Void) -> AnyObject
  func activate(_ application: RunningApplication) throws
  func hide(_ application: RunningApplication) throws
  func hideOthers(except application: RunningApplication) throws
  func quit(_ application: RunningApplication) throws
  func forceQuit(_ application: RunningApplication) throws
  func relaunch(_ application: RunningApplication) async throws
}

/// Resumes a continuation once, whichever of termination, refusal, or timeout happens first.
private final class ContinuationResumer: @unchecked Sendable {
  private let lock = NSLock()
  private var continuation: CheckedContinuation<Void, Error>?
  private var pendingResult: Result<Void, Error>?

  func start(_ continuation: CheckedContinuation<Void, Error>) {
    lock.lock()
    defer { lock.unlock() }

    if let pendingResult {
      continuation.resume(with: pendingResult)
    } else {
      self.continuation = continuation
    }
  }

  func resume() {
    finish(.success(()))
  }

  func resume(throwing error: Error) {
    finish(.failure(error))
  }

  private func finish(_ result: Result<Void, Error>) {
    lock.lock()
    defer { lock.unlock() }

    if let continuation {
      self.continuation = nil
      pendingResult = .failure(CancellationError())
      continuation.resume(with: result)
    } else if pendingResult == nil {
      pendingResult = result
    }
  }
}

private final class WorkspaceApplicationObservation {
  private static let names = [
    NSWorkspace.didLaunchApplicationNotification,
    NSWorkspace.didTerminateApplicationNotification,
    NSWorkspace.didHideApplicationNotification,
    NSWorkspace.didUnhideApplicationNotification,
  ]

  private let observers: [NSObjectProtocol]

  init(onChange: @escaping @MainActor @Sendable () -> Void) {
    observers = Self.names.map { name in
      NSWorkspace.shared.notificationCenter.addObserver(
        forName: name,
        object: nil,
        queue: .main
      ) { _ in
        MainActor.assumeIsolated { onChange() }
      }
    }
  }

  deinit {
    observers.forEach(NSWorkspace.shared.notificationCenter.removeObserver)
  }
}

private enum RunningApplicationActionError: LocalizedError {
  case didNotQuit
  case noBundle
  case notActivated
  case notHidden
  case notQuit
  case notRunning

  var errorDescription: String? {
    switch self {
    case .didNotQuit: "The app did not quit."
    case .noBundle: "The app has no bundle to reopen."
    case .notActivated: "The app did not come to the front."
    case .notHidden: "The app could not be hidden."
    case .notQuit: "The app refused to quit."
    case .notRunning: "The app is no longer running."
    }
  }
}
