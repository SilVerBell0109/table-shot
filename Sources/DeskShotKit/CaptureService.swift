import Foundation
import CoreGraphics

/// 캡처 핵심 로직. 프레임 획득 → PNG 인코딩 → 클립보드 복사(먼저) → 저장.
public final class CaptureService {
    private let frameProvider: () -> CGImage?
    private let fileWriter: FileWriting
    private let clipboard: Clipboarding
    private let settings: SettingsStore
    private let clock: CaptureClock

    public init(
        frameProvider: @escaping () -> CGImage?,
        fileWriter: FileWriting,
        clipboard: Clipboarding,
        settings: SettingsStore,
        clock: CaptureClock
    ) {
        self.frameProvider = frameProvider
        self.fileWriter = fileWriter
        self.clipboard = clipboard
        self.settings = settings
        self.clock = clock
    }

    /// 캡처를 수행하고 저장된 파일 URL을 반환한다.
    @discardableResult
    public func capture() throws -> URL {
        guard let image = frameProvider() else { throw CaptureError.noFrame }
        guard let data = PngEncoder.encode(image) else { throw CaptureError.encodeFailed }

        // 저장이 실패하더라도 클립보드 복사는 먼저 수행한다.
        clipboard.writePNG(data)

        let folder = settings.saveFolderURL
        let url = uniqueURL(in: folder, base: timestamp())
        do {
            try fileWriter.ensureFolder(folder)
            try fileWriter.write(data, to: url)
        } catch {
            throw CaptureError.saveFailed
        }
        return url
    }

    private func timestamp() -> String {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.timeZone = TimeZone.current
        fmt.dateFormat = "yyyyMMdd-HHmmss"
        return fmt.string(from: clock.now())
    }

    /// 같은 초에 여러 번 찍어도 덮어쓰지 않도록 중복 시 -2, -3… 접미사를 붙인다.
    private func uniqueURL(in folder: URL, base: String) -> URL {
        let first = folder.appendingPathComponent("desk-\(base).png")
        guard fileWriter.fileExists(at: first) else { return first }
        var n = 2
        while true {
            let candidate = folder.appendingPathComponent("desk-\(base)-\(n).png")
            if !fileWriter.fileExists(at: candidate) { return candidate }
            n += 1
        }
    }
}
