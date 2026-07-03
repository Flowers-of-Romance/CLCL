import AppKit
import Carbon.HIToolbox

/// Global hotkey via Carbon RegisterEventHotKey (no Accessibility permission needed).
/// Default is Option+C, mirroring the original CLCL's Alt+C.
final class HotKey {
    private static var nextID: UInt32 = 1

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private let handler: () -> Void
    private let id: UInt32

    init(keyCode: UInt32 = UInt32(kVK_ANSI_C),
         modifiers: UInt32 = UInt32(optionKey),
         handler: @escaping () -> Void) {
        self.handler = handler
        self.id = HotKey.nextID
        HotKey.nextID += 1

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                      eventKind: UInt32(kEventHotKeyPressed))
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetApplicationEventTarget(), { _, event, userData in
            guard let userData else { return noErr }
            let me = Unmanaged<HotKey>.fromOpaque(userData).takeUnretainedValue()
            // Every HotKey instance's handler sees every hotkey press;
            // only react to our own registration.
            var pressed = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject),
                              EventParamType(typeEventHotKeyID), nil,
                              MemoryLayout<EventHotKeyID>.size, nil, &pressed)
            guard pressed.id == me.id else { return noErr }
            me.handler()
            return noErr
        }, 1, &eventType, selfPtr, &eventHandler)

        let hotKeyID = EventHotKeyID(signature: OSType(0x434C_434C) /* 'CLCL' */, id: id)
        RegisterEventHotKey(keyCode, modifiers, hotKeyID,
                            GetApplicationEventTarget(), 0, &hotKeyRef)
    }

    deinit {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        if let eventHandler { RemoveEventHandler(eventHandler) }
    }
}
