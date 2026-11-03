import XCTest
@testable import DeskShotKit

final class SettingsStoreTests: XCTestCase {
    private func makeEphemeralDefaults() -> UserDefaults {
        UserDefaults(suiteName: UUID().uuidString)!
    }

    func test_defaultSaveFolder_isPicturesDeskShots() {
        let s = SettingsStore(defaults: makeEphemeralDefaults())
        XCTAssertEqual(s.saveFolderURL.lastPathComponent, "DeskShots")
        XCTAssertTrue(s.saveFolderURL.path.contains("/Pictures/"))
    }

    func test_persistsSaveFolder() {
        let d = makeEphemeralDefaults()
        SettingsStore(defaults: d).saveFolderURL = URL(fileURLWithPath: "/tmp/x")
        XCTAssertEqual(SettingsStore(defaults: d).saveFolderURL.path, "/tmp/x")
    }

    func test_defaultHotkey_isCmdShift2() {
        let s = SettingsStore(defaults: makeEphemeralDefaults())
        XCTAssertEqual(s.hotkey, HotkeySpec.defaultCapture)
    }

    func test_persistsHotkey() {
        let d = makeEphemeralDefaults()
        let custom = HotkeySpec(keyCode: 20, modifiers: 256)
        SettingsStore(defaults: d).hotkey = custom
        XCTAssertEqual(SettingsStore(defaults: d).hotkey, custom)
    }
}
