import Testing

@testable import Conjuror

@MainActor
@Suite("Launch At Login Store")
struct LaunchAtLoginStoreTests {
  private enum TestError: Error {
    case failed
  }

  @Test("Unregistered services default to off")
  func testDefaultsToOff() {
    let store = LaunchAtLoginStore(service: LaunchAtLoginServiceStub(status: .notRegistered))

    #expect(!store.isEnabled)
    #expect(store.errorMessage == nil)
  }

  @Test("Enabling registers the service")
  func testEnablesService() {
    let service = LaunchAtLoginServiceStub(status: .notRegistered)
    let store = LaunchAtLoginStore(service: service)

    store.setEnabled(true)

    #expect(service.registerCallCount == 1)
    #expect(store.isEnabled)
    #expect(store.status == .enabled)
  }

  @Test("Disabling unregisters the service")
  func testDisablesService() {
    let service = LaunchAtLoginServiceStub(status: .enabled)
    let store = LaunchAtLoginStore(service: service)

    store.setEnabled(false)

    #expect(service.unregisterCallCount == 1)
    #expect(!store.isEnabled)
    #expect(store.status == .notRegistered)
  }

  @Test("Approval-required registrations remain selected")
  func testRequiresApproval() {
    let service = LaunchAtLoginServiceStub(
      status: .notRegistered,
      statusAfterRegister: .requiresApproval
    )
    let store = LaunchAtLoginStore(service: service)

    store.setEnabled(true)

    #expect(store.isEnabled)
    #expect(store.status == .requiresApproval)
  }

  @Test("Failures expose an error and refresh status")
  func testReportsFailure() {
    let service = LaunchAtLoginServiceStub(status: .notRegistered, error: TestError.failed)
    let store = LaunchAtLoginStore(service: service)

    store.setEnabled(true)

    #expect(!store.isEnabled)
    #expect(store.errorMessage?.hasPrefix("Couldn’t update launch at login.") == true)
  }

  @Test("Launch at login: Login Items settings can be opened")
  func testOpensLoginItemsSettings() {
    var didOpenSettings = false
    let store = LaunchAtLoginStore(
      service: LaunchAtLoginServiceStub(status: .requiresApproval),
      openLoginItemsSettings: { didOpenSettings = true }
    )

    store.openLoginItemsSettings()

    #expect(didOpenSettings)
  }
}

private final class LaunchAtLoginServiceStub: LaunchAtLoginServicing {
  var status: LaunchAtLoginStatus
  private(set) var registerCallCount = 0
  private(set) var unregisterCallCount = 0

  private let statusAfterRegister: LaunchAtLoginStatus
  private let error: Error?

  init(
    status: LaunchAtLoginStatus,
    statusAfterRegister: LaunchAtLoginStatus = .enabled,
    error: Error? = nil
  ) {
    self.status = status
    self.statusAfterRegister = statusAfterRegister
    self.error = error
  }

  func register() throws {
    registerCallCount += 1

    if let error { throw error }
    status = statusAfterRegister
  }

  func unregister() throws {
    unregisterCallCount += 1

    if let error { throw error }
    status = .notRegistered
  }
}
