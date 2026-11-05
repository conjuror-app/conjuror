import Carbon.HIToolbox
import Foundation
import Synchronization

final class GlobalHotKey {
  private static let signature: OSType = 0x434F_4E4A  // CONJ
  /// Gives each hot key its own ID, so handlers never respond to another hot key's presses.
  private static let lastIdentifier = Atomic<UInt32>(0)

  private var eventHandler: EventHandlerRef?
  private var hotKey: EventHotKeyRef?
  private let handler: () -> Void
  private let identifier = GlobalHotKey.lastIdentifier.add(1, ordering: .relaxed).newValue

  init(
    configuration: HotKeyConfiguration,
    handler: @escaping () -> Void
  ) throws {
    self.handler = handler

    var eventType = EventTypeSpec(
      eventClass: OSType(kEventClassKeyboard),
      eventKind: UInt32(kEventHotKeyPressed)
    )
    let installStatus = InstallEventHandler(
      GetApplicationEventTarget(),
      { _, event, userData in
        guard let event, let userData else {
          return OSStatus(eventNotHandledErr)
        }

        let globalHotKey = Unmanaged<GlobalHotKey>
          .fromOpaque(userData)
          .takeUnretainedValue()
        var hotKeyID = EventHotKeyID()
        let status = GetEventParameter(
          event,
          EventParamName(kEventParamDirectObject),
          EventParamType(typeEventHotKeyID),
          nil,
          MemoryLayout<EventHotKeyID>.size,
          nil,
          &hotKeyID
        )

        guard status == noErr, hotKeyID.id == globalHotKey.identifier else {
          return OSStatus(eventNotHandledErr)
        }

        globalHotKey.handler()

        return noErr
      },
      1,
      &eventType,
      Unmanaged.passUnretained(self).toOpaque(),
      &eventHandler
    )

    guard installStatus == noErr else {
      throw GlobalHotKeyError.installEventHandler(installStatus)
    }

    let hotKeyID = EventHotKeyID(signature: Self.signature, id: identifier)
    let registrationStatus = RegisterEventHotKey(
      configuration.keyCode,
      configuration.modifiers,
      hotKeyID,
      GetApplicationEventTarget(),
      0,
      &hotKey
    )

    guard registrationStatus == noErr else {
      if let eventHandler {
        RemoveEventHandler(eventHandler)
      }

      eventHandler = nil
      throw GlobalHotKeyError.registerHotKey(
        configuration.displayName,
        registrationStatus
      )
    }
  }

  deinit {
    if let hotKey {
      UnregisterEventHotKey(hotKey)
    }

    if let eventHandler {
      RemoveEventHandler(eventHandler)
    }
  }
}

private enum GlobalHotKeyError: LocalizedError {
  case installEventHandler(OSStatus)
  case registerHotKey(String, OSStatus)

  var errorDescription: String? {
    switch self {
    case let .installEventHandler(status):
      return "Couldn’t install the keyboard event handler (OSStatus \(status))."
    case let .registerHotKey(displayName, status):
      return "\(displayName) is already in use or unavailable (OSStatus \(status))."
    }
  }
}
