import Carbon

/// Carbon's registered shortcut works globally without keyboard monitoring permissions.
final class DanceHotKey {
    private var hotKey: EventHotKeyRef?
    private var handler: EventHandlerRef?
    private var latch = HotKeyPressLatch()
    private let action: () -> Void
    private static let signature: OSType = 0x57414444 // WADD

    init(action: @escaping () -> Void) {
        self.action = action
        var types = [
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed)),
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyReleased))
        ]
        let status = InstallEventHandler(GetApplicationEventTarget(), { _, event, context in
            guard let event, let context else { return OSStatus(eventNotHandledErr) }
            let owner = Unmanaged<DanceHotKey>.fromOpaque(context).takeUnretainedValue()
            var id = EventHotKeyID()
            let result = GetEventParameter(event, EventParamName(kEventParamDirectObject),
                                          EventParamType(typeEventHotKeyID), nil,
                                          MemoryLayout<EventHotKeyID>.size, nil, &id)
            guard result == noErr, id.signature == DanceHotKey.signature, id.id == 1 else {
                return OSStatus(eventNotHandledErr)
            }
            let pressed = GetEventKind(event) == UInt32(kEventHotKeyPressed)
            if owner.latch.receive(pressed: pressed) { owner.action() }
            return noErr
        }, types.count, &types, Unmanaged.passUnretained(self).toOpaque(), &handler)
        guard status == noErr else { return }
        let id = EventHotKeyID(signature: Self.signature, id: 1)
        let registration = RegisterEventHotKey(UInt32(kVK_ANSI_D), UInt32(optionKey), id,
                                               GetApplicationEventTarget(), 0, &hotKey)
        if registration != noErr {
            // A conflicting shortcut still leaves the status-menu dance action available.
            stop()
        }
    }

    func stop() {
        if let hotKey { UnregisterEventHotKey(hotKey) }
        if let handler { RemoveEventHandler(handler) }
        hotKey = nil
        handler = nil
        latch = HotKeyPressLatch()
    }

    deinit { stop() }
}

/// Repeated press events must not toggle dance until the shortcut is released.
struct HotKeyPressLatch {
    private var down = false

    mutating func receive(pressed: Bool) -> Bool {
        let shouldFire = pressed && !down
        down = pressed
        return shouldFire
    }
}
