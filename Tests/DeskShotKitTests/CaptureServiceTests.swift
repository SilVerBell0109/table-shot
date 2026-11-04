import XCTest
import CoreGraphics
@testable import DeskShotKit

// MARK: - 테스트 더블

private final class FileSpy: FileWriting {
    var ensuredFolders: [URL] = []
    var writtenURLs: [URL] = []
    var failOnWrite = false
    var existingPaths: Set<String> = []
    var anyWrite: Bool { !writtenURLs.isEmpty }

    func ensureFolder(_ url: URL) throws { ensuredFolders.append(url) }
    func write(_ data: Data, to url: URL) throws {
        if failOnWrite { throw CaptureError.saveFailed }
        writtenURLs.append(url)
    }
    func fileExists(at url: URL) -> Bool { existingPaths.contains(url.path) }
    func wrote(to url: URL) -> Bool { writtenURLs.contains(url) }
}

private final class ClipSpy: Clipboarding {
    var called = false
    func writePNG(_ data: Data) { called = true }
}

private struct FixedClock: CaptureClock {
    let date: Date
    func now() -> Date { date }
}

final class CaptureServiceTests: XCTestCase {
    private func make1x1CGImage() -> CGImage {
        let cs = CGColorSpaceCreateDeviceRGB()
        let ctx = CGContext(
            data: nil, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
            space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
        return ctx.makeImage()!
    }

    private func makeSettings(folder: String) -> SettingsStore {
        let s = SettingsStore(defaults: UserDefaults(suiteName: UUID().uuidString)!)
        s.saveFolderURL = URL(fileURLWithPath: folder)
        return s
    }

    // 2026-11-03 17:19:00 로컬 시각
    private func fixedDate() -> Date {
        var c = DateComponents()
        c.year = 2026; c.month = 11; c.day = 3
        c.hour = 17; c.minute = 19; c.second = 0
        return Calendar(identifier: .gregorian).date(from: c)!
    }

    func test_capture_savesAndCopies_returnsExpectedURL() throws {
        let fileSpy = FileSpy(); let clipSpy = ClipSpy()
        let settings = makeSettings(folder: "/tmp/ds")
        let img = make1x1CGImage()
        let sut = CaptureService(
            frameProvider: { img }, fileWriter: fileSpy, clipboard: clipSpy,
            settings: settings, clock: FixedClock(date: fixedDate()))

        let url = try sut.capture()

        XCTAssertEqual(url.lastPathComponent, "desk-20261103-171900.png")
        XCTAssertTrue(fileSpy.wrote(to: url))
        XCTAssertTrue(clipSpy.called)
    }

    // 단발 캡처는 하위 폴더를 만들지 않고 저장 폴더에 바로 저장한다.
    // (미리보기 "폴더 열기"는 저장 폴더에서 그 파일을 선택해 연다)
    func test_capture_savesDirectlyInSaveFolder() throws {
        let fileSpy = FileSpy(); let clipSpy = ClipSpy()
        let settings = makeSettings(folder: "/tmp/ds")
        let img = make1x1CGImage()
        let sut = CaptureService(
            frameProvider: { img }, fileWriter: fileSpy, clipboard: clipSpy,
            settings: settings, clock: FixedClock(date: fixedDate()))

        let url = try sut.capture()

        let folder = url.deletingLastPathComponent()
        XCTAssertEqual(folder.path, "/tmp/ds")   // 하위 폴더 없음
        XCTAssertEqual(url.lastPathComponent, "desk-20261103-171900.png")
    }

    // 자동(연속) 캡처: subfolder를 주면 그 세션 폴더 하나에 모아 저장한다.
    // (3초 간격 버스트 한 세션의 사진들이 흩어지지 않게)
    func test_capture_withSubfolder_savesIntoThatSubfolder() throws {
        let fileSpy = FileSpy(); let clipSpy = ClipSpy()
        let settings = makeSettings(folder: "/tmp/ds")
        let img = make1x1CGImage()
        let sut = CaptureService(
            frameProvider: { img }, fileWriter: fileSpy, clipboard: clipSpy,
            settings: settings, clock: FixedClock(date: fixedDate()))

        let url = try sut.capture(subfolder: "burst-20261103-171900")

        let folder = url.deletingLastPathComponent()
        XCTAssertEqual(folder.lastPathComponent, "burst-20261103-171900")
        XCTAssertEqual(folder.deletingLastPathComponent().path, "/tmp/ds")
        XCTAssertEqual(url.lastPathComponent, "desk-20261103-171900.png")
        XCTAssertTrue(fileSpy.wrote(to: url))
    }

    func test_capture_noFrame_throws() {
        let fileSpy = FileSpy(); let clipSpy = ClipSpy()
        let sut = CaptureService(
            frameProvider: { nil }, fileWriter: fileSpy, clipboard: clipSpy,
            settings: makeSettings(folder: "/tmp/ds"), clock: FixedClock(date: fixedDate()))

        XCTAssertThrowsError(try sut.capture()) { XCTAssertEqual($0 as? CaptureError, .noFrame) }
        XCTAssertFalse(fileSpy.anyWrite)
        XCTAssertFalse(clipSpy.called)
    }

    func test_capture_saveFailure_stillCopiesClipboard() {
        let fileSpy = FileSpy(); fileSpy.failOnWrite = true
        let clipSpy = ClipSpy()
        let img = make1x1CGImage()
        let sut = CaptureService(
            frameProvider: { img }, fileWriter: fileSpy, clipboard: clipSpy,
            settings: makeSettings(folder: "/tmp/ds"), clock: FixedClock(date: fixedDate()))

        XCTAssertThrowsError(try sut.capture()) { XCTAssertEqual($0 as? CaptureError, .saveFailed) }
        XCTAssertTrue(clipSpy.called) // 저장 실패해도 클립보드는 시도됨
    }

    func test_capture_whenFileExists_dedupesFilename() throws {
        let fileSpy = FileSpy(); let clipSpy = ClipSpy()
        let settings = makeSettings(folder: "/tmp/ds")
        fileSpy.existingPaths = ["/tmp/ds/desk-20261103-171900.png"]
        let img = make1x1CGImage()
        let sut = CaptureService(
            frameProvider: { img }, fileWriter: fileSpy, clipboard: clipSpy,
            settings: settings, clock: FixedClock(date: fixedDate()))

        let url = try sut.capture()

        XCTAssertEqual(url.lastPathComponent, "desk-20261103-171900-2.png")
        XCTAssertTrue(fileSpy.wrote(to: url))
    }

    func test_capture_createsSaveFolderIfMissing() throws {
        let fileSpy = FileSpy(); let clipSpy = ClipSpy()
        let settings = makeSettings(folder: "/tmp/ds")
        let img = make1x1CGImage()
        let sut = CaptureService(
            frameProvider: { img }, fileWriter: fileSpy, clipboard: clipSpy,
            settings: settings, clock: FixedClock(date: fixedDate()))

        _ = try sut.capture()

        // 단발 캡처는 저장 폴더 자체만 보장한다(하위 폴더 생성 없음).
        XCTAssertTrue(fileSpy.ensuredFolders.contains(settings.saveFolderURL))
    }
}
