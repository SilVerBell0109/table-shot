import Carbon.HIToolbox
import DeskShotKit

/// Carbon RegisterEventHotKey 기반 전역 핫키. (손쉬운 사용 권한 불필요)
final class HotkeyManager {
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private var onTrigger: (() -> Void)?

    private static let signature: OSType = {
        // 'DSHT'
        let chars: [UInt8] = Array("DSHT".utf8)
        return chars.reduce(0) { ($0 << 8) + OSType($1) }
    }()
    private let hotKeyID = EventHotKeyID(signature: HotkeyManager.signature, id: 1)

    func register(_ spec: HotkeySpec, onTrigger: @escaping () -> Void) {
        unregister()
        self.onTrigger = onTrigger

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed))

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetApplicationEventTarget(), { _, event, userData -> OSStatus in
            guard let userData else { return noErr }
            let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
            var hkID = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject),
                              EventParamType(typeEventHotKeyID), nil,
                              MemoryLayout<EventHotKeyID>.size, nil, &hkID)
            if hkID.id == manager.hotKeyID.id {
                manager.onTrigger?()
            }
            return noErr
        }, 1, &eventType, selfPtr, &eventHandler)

        RegisterEventHotKey(spec.keyCode, spec.modifiers, hotKeyID,
                            GetApplicationEventTarget(), 0, &hotKeyRef)
    }

    func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        if let eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
        }
        onTrigger = nil
    }

    deinit { unregister() }
}
