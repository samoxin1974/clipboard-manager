import Foundation
import Carbon.HIToolbox
import AppKit

final class HotkeyController {
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private let signature: OSType = 0x434C4950
    private let identifier: UInt32 = 1

    var onHotkey: (() -> Void)?

    init() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, _, userData -> OSStatus in
                guard let userData else { return noErr }
                let controller = Unmanaged<HotkeyController>.fromOpaque(userData).takeUnretainedValue()
                DispatchQueue.main.async {
                    controller.onHotkey?()
                }
                return noErr
            },
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandler
        )
    }

    deinit {
        unregister()
        if let eventHandler {
            RemoveEventHandler(eventHandler)
        }
    }

    func register(_ shortcut: GlobalShortcut) throws {
        unregister()
        var reference: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: signature, id: identifier)
        let status = RegisterEventHotKey(
            shortcut.keyCode,
            shortcut.carbonModifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &reference
        )
        guard status == noErr, reference != nil else {
            throw HotkeyError.registrationFailed(status)
        }
        hotKeyRef = reference
    }

    func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
    }
}

enum HotkeyError: LocalizedError {
    case registrationFailed(OSStatus)

    var errorDescription: String? {
        switch self {
        case let .registrationFailed(status):
            return "The shortcut could not be registered (status \(status)). Choose another shortcut."
        }
    }
}
