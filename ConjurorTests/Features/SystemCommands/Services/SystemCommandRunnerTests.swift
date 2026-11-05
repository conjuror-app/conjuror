import Carbon.HIToolbox
import CoreServices
import Foundation
import Testing

@testable import Conjuror

@Suite("System Command Runner")
struct SystemCommandRunnerTests {
  @Test("Eject All Disks keeps removable and ejectable volumes except the startup disk")
  func testEjectableVolumes() {
    let volumes = [
      volume("Macintosh HD", isRootFileSystem: true),
      volume("Data"),
      volume("Installer", isEjectable: true),
      volume("Card", isRemovable: true),
      volume("Root Image", isEjectable: true, isRootFileSystem: true),
    ]

    #expect(
      SystemCommandRunner.ejectableVolumes(from: volumes).map(\.lastPathComponent)
        == ["Installer", "Card"]
    )
  }

  @Test("Apple event consent errors name the app to allow in Automation settings")
  func testPermissionErrors() {
    #expect(
      SystemAppleEvents.error(code: Int(errAEEventNotPermitted), target: .finder)
        == .permissionDenied(appName: "Finder")
    )
    #expect(
      SystemAppleEvents.error(code: -10004, target: .systemEvents)
        == .permissionDenied(appName: "System Events")
    )
    #expect(SystemAppleEvents.error(code: -600, target: .finder) == .failed(code: -600))
  }

  @Test("Held Return or Enter repeats are ignored, but a new press is not")
  func testRepeatedSubmit() {
    #expect(
      LauncherKeyboardNavigation.isRepeatedSubmit(keyCode: UInt16(kVK_Return), isARepeat: true)
    )
    #expect(
      LauncherKeyboardNavigation.isRepeatedSubmit(
        keyCode: UInt16(kVK_ANSI_KeypadEnter),
        isARepeat: true
      )
    )
    #expect(
      !LauncherKeyboardNavigation.isRepeatedSubmit(keyCode: UInt16(kVK_Return), isARepeat: false)
    )
    #expect(
      !LauncherKeyboardNavigation.isRepeatedSubmit(keyCode: UInt16(kVK_DownArrow), isARepeat: true)
    )
  }

  private func volume(
    _ name: String,
    isEjectable: Bool = false,
    isRemovable: Bool = false,
    isRootFileSystem: Bool = false
  ) -> SystemCommandRunner.Volume {
    SystemCommandRunner.Volume(
      url: URL(fileURLWithPath: "/Volumes/\(name)"),
      isEjectable: isEjectable,
      isRemovable: isRemovable,
      isRootFileSystem: isRootFileSystem
    )
  }
}
