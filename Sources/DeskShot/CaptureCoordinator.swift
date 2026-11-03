import Foundation
import AppKit
import DeskShotKit

/// 세 트리거(핫키·메뉴바·버튼)가 모두 수렴하는 지점.
/// CaptureService를 실제 포트로 조립하고, 캡처 후 피드백을 준다.
@MainActor
final class CaptureCoordinator: ObservableObject {
    @Published var lastSavedURL: URL?
    @Published var lastErrorMessage: String?

    private let camera: CameraManager
    private let service: CaptureService

    init(camera: CameraManager, settings: SettingsStore) {
        self.camera = camera
        self.service = CaptureService(
            frameProvider: { [weak camera] in camera?.latestFrame() },
            fileWriter: FileManagerWriter(),
            clipboard: PasteboardClipboard(),
            settings: settings,
            clock: SystemClock())
    }

    /// 세 경로 공통 진입점.
    func trigger() {
        do {
            let url = try service.capture()
            lastSavedURL = url
            lastErrorMessage = nil
            giveSuccessFeedback()
        } catch {
            lastErrorMessage = Self.message(for: error)
            NSSound.beep()
        }
    }

    private func giveSuccessFeedback() {
        // 셔터음 + 화면 가장자리 플래시
        Self.shutterSound?.play()
        EdgeFlash.flash()
    }

    // NSSound(named: "Grab")은 앱 번들/표준 Sounds 폴더만 검색하므로 nil이 된다.
    // 스크린샷 셔터음(Grab.aif)을 절대 경로로 로드하고, 없으면 Pop으로 대체한다.
    private static let shutterSound: NSSound? = {
        let grab = "/System/Library/Components/CoreAudio.component/Contents/SharedSupport/SystemSounds/system/Grab.aif"
        if FileManager.default.fileExists(atPath: grab),
           let s = NSSound(contentsOfFile: grab, byReference: true) {
            return s
        }
        return NSSound(named: "Pop")
    }()

    private static func message(for error: Error) -> String {
        switch error as? CaptureError {
        case .noFrame: return "아직 카메라 프레임이 준비되지 않았습니다. 잠시 후 다시 시도하세요."
        case .encodeFailed: return "이미지 인코딩에 실패했습니다."
        case .saveFailed: return "파일 저장에 실패했습니다. (클립보드에는 복사되었습니다)"
        case .none: return "캡처 중 알 수 없는 오류가 발생했습니다."
        }
    }
}

/// 캡처 순간 화면 가장자리를 잠깐 밝혔다 사라지게 하는 간단한 피드백.
enum EdgeFlash {
    static func flash() {
        guard let screen = NSScreen.main else { return }
        let window = NSWindow(
            contentRect: screen.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .screenSaver
        window.ignoresMouseEvents = true
        window.hasShadow = false

        let border = NSView(frame: screen.frame)
        border.wantsLayer = true
        border.layer?.borderColor = NSColor.white.cgColor
        border.layer?.borderWidth = 8
        window.contentView = border
        window.alphaValue = 0.9
        window.orderFrontRegardless()

        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.35
            window.animator().alphaValue = 0
        }, completionHandler: {
            window.orderOut(nil)
        })
    }
}
