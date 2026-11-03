import Foundation

/// 전역 핫키 명세. keyCode/modifiers는 Carbon 가상 키코드/수정자 비트.
/// (DeskShotKit은 순수 로직만 두므로 Carbon 심볼 대신 숫자값을 쓴다)
public struct HotkeySpec: Equatable {
    public var keyCode: UInt32
    public var modifiers: UInt32

    public init(keyCode: UInt32, modifiers: UInt32) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    /// 기본 캡처 핫키: ⌘⇧2
    /// keyCode 0x13(=19) = ANSI '2', modifiers = cmdKey(256) | shiftKey(512) = 768
    public static let defaultCapture = HotkeySpec(keyCode: 0x13, modifiers: 256 | 512)
}

/// UserDefaults 기반 설정 저장소.
public final class SettingsStore {
    private let defaults: UserDefaults

    private enum Key {
        static let saveFolderPath = "saveFolderPath"
        static let hotkeyKeyCode = "hotkeyKeyCode"
        static let hotkeyModifiers = "hotkeyModifiers"
    }

    public init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    /// 저장 폴더. 기본값은 ~/Pictures/DeskShots.
    public var saveFolderURL: URL {
        get {
            if let path = defaults.string(forKey: Key.saveFolderPath) {
                return URL(fileURLWithPath: path)
            }
            return Self.defaultSaveFolder
        }
        set {
            defaults.set(newValue.path, forKey: Key.saveFolderPath)
        }
    }

    /// 전역 캡처 핫키. 기본값은 ⌘⇧2.
    public var hotkey: HotkeySpec {
        get {
            guard defaults.object(forKey: Key.hotkeyKeyCode) != nil,
                  defaults.object(forKey: Key.hotkeyModifiers) != nil else {
                return .defaultCapture
            }
            return HotkeySpec(
                keyCode: UInt32(defaults.integer(forKey: Key.hotkeyKeyCode)),
                modifiers: UInt32(defaults.integer(forKey: Key.hotkeyModifiers)))
        }
        set {
            defaults.set(Int(newValue.keyCode), forKey: Key.hotkeyKeyCode)
            defaults.set(Int(newValue.modifiers), forKey: Key.hotkeyModifiers)
        }
    }

    private static var defaultSaveFolder: URL {
        let pictures = FileManager.default
            .urls(for: .picturesDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Pictures")
        return pictures.appendingPathComponent("DeskShots")
    }
}
