import Foundation
import AppKit
import DeskShotKit

/// 세 트리거(핫키·메뉴바·버튼)가 모두 수렴하는 지점.
/// CaptureService를 실제 포트로 조립하고, 캡처 후 피드백을 준다.
@MainActor
final class CaptureCoordinator: ObservableObject {
    @Published var lastSavedURL: URL?
    @Published var lastErrorMessage: String?
    /// 자동(연속) 캡처가 동작 중인지. 메뉴·버튼 레이블이 이 값을 따른다.
    @Published private(set) var isIntervalRunning = false

    private let camera: CameraManager
    private let service: CaptureService

    /// 자동 캡처 간격(초). 요구사항: 3초마다 1장.
    static let intervalSeconds: TimeInterval = 3

    private var intervalTimer: Timer?
    /// 이번 자동 캡처 세션의 사진을 모을 폴더 이름.
    private var intervalFolder: String?

    init(camera: CameraManager, settings: SettingsStore) {
        self.camera = camera
        self.service = CaptureService(
            frameProvider: { [weak camera] in camera?.latestFrame() },
            fileWriter: FileManagerWriter(),
            clipboard: PasteboardClipboard(),
            settings: settings,
            clock: SystemClock())
    }

    /// 세 경로(핫키·메뉴바·버튼) 공통 단발 캡처 진입점.
    func trigger() {
        performCapture(subfolder: nil, playSound: true)
    }

    /// 자동 캡처 토글. 동작 중이면 멈추고, 아니면 시작한다.
    func toggleInterval() {
        isIntervalRunning ? stopInterval() : startInterval()
    }

    /// 자동 캡처 시작: 즉시 1장 찍고 이후 intervalSeconds마다 1장씩.
    func startInterval() {
        guard !isIntervalRunning else { return }
        camera.start()   // 프레임이 필요하므로 세션을 확실히 켠다.
        // 이번 세션 사진을 모을 폴더 이름을 한 번만 정한다.
        intervalFolder = "burst-" + Self.folderStamp()
        isIntervalRunning = true

        // 첫 장은 바로 찍고(셔터음 1회), 이후는 소리 없이 조용히 반복한다.
        performCapture(subfolder: intervalFolder, playSound: true)
        let timer = Timer.scheduledTimer(withTimeInterval: Self.intervalSeconds, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.intervalTick() }
        }
        intervalTimer = timer
    }

    /// 자동 캡처 중지.
    func stopInterval() {
        intervalTimer?.invalidate()
        intervalTimer = nil
        intervalFolder = nil
        isIntervalRunning = false
    }

    private func intervalTick() {
        guard isIntervalRunning else { return }
        // 반복 중엔 셔터음 없이 가장자리 플래시로만 알린다(3초마다 울리면 거슬림).
        performCapture(subfolder: intervalFolder, playSound: false)
    }

    private func performCapture(subfolder: String?, playSound: Bool) {
        do {
            let url = try service.capture(subfolder: subfolder)
            lastSavedURL = url
            lastErrorMessage = nil
            if playSound { Self.shutterSound?.play() }
            EdgeFlash.flash()
        } catch {
            lastErrorMessage = Self.message(for: error)
            NSSound.beep()
            // 자동 캡처 중 오류가 나면(예: 프레임 없음) 계속 삑삑대지 않도록 멈춘다.
            if isIntervalRunning { stopInterval() }
        }
    }

    /// 자동 캡처 세션 폴더 이름에 쓸 시각 문자열.
    private static func folderStamp() -> String {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.timeZone = .current
        fmt.dateFormat = "yyyyMMdd-HHmmss"
        return fmt.string(from: Date())
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
