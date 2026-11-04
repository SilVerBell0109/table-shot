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
        static let rotationDegrees = "rotationDegrees"
    }

    /// 기본 미리보기/캡처 회전각(도). 사용자가 보는 방향으로 둔 책상 위 문서는
    /// 데스크 뷰 원본에서 이미 바로 선 상태로 들어오므로 0°(회전 없음)가 기본이다.
    /// (화면이 뒤집혀 보이면 미리보기의 "회전" 버튼으로 90°씩 돌려 설정에 저장한다.)
    public static let defaultRotationDegrees = 0

    /// 임의의 각도를 0/90/180/270 중 가장 가까운 값으로 정규화한다(음수·360 이상도 감싼다).
    public static func normalizedRotation(_ degrees: Int) -> Int {
        let quarters = Int((Double(degrees) / 90.0).rounded())
        return (((quarters % 4) + 4) % 4) * 90
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

    /// 미리보기·저장 PNG에 적용할 회전각(도). 0/90/180/270으로 정규화되어 저장된다. 기본 0°.
    public var rotationDegrees: Int {
        get {
            guard defaults.object(forKey: Key.rotationDegrees) != nil else {
                return Self.defaultRotationDegrees
            }
            return Self.normalizedRotation(defaults.integer(forKey: Key.rotationDegrees))
        }
        set {
            defaults.set(Self.normalizedRotation(newValue), forKey: Key.rotationDegrees)
        }
    }

    private static var defaultSaveFolder: URL {
        let pictures = FileManager.default
            .urls(for: .picturesDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Pictures")
        return pictures.appendingPathComponent("DeskShots")
    }
}
