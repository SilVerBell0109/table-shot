import Foundation

/// 저장 폴더 보장 + 파일 쓰기 포트. (플랫폼 구현은 DeskShot 실행 타깃에서 주입)
public protocol FileWriting {
    func ensureFolder(_ url: URL) throws
    func write(_ data: Data, to url: URL) throws
    func fileExists(at url: URL) -> Bool
}

/// 클립보드에 PNG를 올리는 포트.
public protocol Clipboarding {
    func writePNG(_ data: Data)
}

/// 현재 시각 공급 포트. (표준 라이브러리 `Clock`과의 충돌을 피하려 CaptureClock으로 명명)
public protocol CaptureClock {
    func now() -> Date
}

/// 캡처 실패 사유.
public enum CaptureError: Error, Equatable {
    case noFrame
    case encodeFailed
    case saveFailed
}
