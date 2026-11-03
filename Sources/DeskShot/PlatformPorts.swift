import Foundation
import AppKit
import DeskShotKit

/// FileManager 기반 파일 쓰기 포트.
struct FileManagerWriter: FileWriting {
    func ensureFolder(_ url: URL) throws {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }
    func write(_ data: Data, to url: URL) throws {
        try data.write(to: url, options: .atomic)
    }
}

/// NSPasteboard 기반 클립보드 포트. PNG 데이터와 NSImage를 모두 기록해 호환성을 높인다.
struct PasteboardClipboard: Clipboarding {
    func writePNG(_ data: Data) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setData(data, forType: .png)
        if let image = NSImage(data: data) {
            pb.writeObjects([image])
        }
    }
}

/// 시스템 시간 포트.
struct SystemClock: CaptureClock {
    func now() -> Date { Date() }
}
