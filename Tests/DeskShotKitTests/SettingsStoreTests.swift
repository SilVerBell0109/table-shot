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

    func test_defaultRotation_is180() {
        let s = SettingsStore(defaults: makeEphemeralDefaults())
        XCTAssertEqual(s.rotationDegrees, 180)
    }

    func test_persistsRotation() {
        let d = makeEphemeralDefaults()
        SettingsStore(defaults: d).rotationDegrees = 90
        XCTAssertEqual(SettingsStore(defaults: d).rotationDegrees, 90)
    }

    func test_rotationIsNormalizedToQuarterTurns() {
        let d = makeEphemeralDefaults()
        let s = SettingsStore(defaults: d)
        s.rotationDegrees = 450          // 450 → 90
        XCTAssertEqual(s.rotationDegrees, 90)
        s.rotationDegrees = -90          // -90 → 270
        XCTAssertEqual(s.rotationDegrees, 270)
    }

    func test_normalizedRotation_snapsAndWraps() {
        XCTAssertEqual(SettingsStore.normalizedRotation(0), 0)
        XCTAssertEqual(SettingsStore.normalizedRotation(270 + 90), 0)   // 360 → 0
        XCTAssertEqual(SettingsStore.normalizedRotation(-90), 270)
        XCTAssertEqual(SettingsStore.normalizedRotation(44), 0)         // snap to nearest 90
        XCTAssertEqual(SettingsStore.normalizedRotation(46), 90)
    }
}
