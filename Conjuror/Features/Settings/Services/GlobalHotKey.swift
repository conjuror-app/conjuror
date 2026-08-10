import Carbon.HIToolbox
import Foundation

final class GlobalHotKey: HotKeyRegistration {
    private static let signature: OSType = 0x434F4E4A // CONJ

    private var eventHandler: EventHandlerRef?
    private var hotKey: EventHotKeyRef?
    private let handler: () -> Void

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
            { _, _, userData in
                guard let userData else {
                    return OSStatus(eventNotHandledErr)
                }

                let globalHotKey = Unmanaged<GlobalHotKey>
                    .fromOpaque(userData)
                    .takeUnretainedValue()
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

        let hotKeyID = EventHotKeyID(signature: Self.signature, id: 1)
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

protocol HotKeyRegistration: AnyObject {}

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
