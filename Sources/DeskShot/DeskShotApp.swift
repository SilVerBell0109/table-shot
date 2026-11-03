import SwiftUI
import AppKit
import AVFoundation
import DeskShotKit

@main
struct DeskShotApp: App {
    @StateObject private var appModel = AppModel()

    var body: some Scene {
        MenuBarExtra("Table_shot", systemImage: "camera.viewfinder") {
            if appModel.isSupported {
                if !appModel.cameraAuthorized {
                    Button("카메라 권한이 필요합니다 — 시스템 설정 열기") { appModel.openCameraSettings() }
                    Divider()
                }
                Button("찍기") { appModel.coordinator?.trigger() }
                    .keyboardShortcut("2", modifiers: [.command, .shift])
                Button("미리보기 열기") { appModel.showPreview() }
                Button("데스크 뷰 영역 맞추기…") { appModel.openDeskViewSetup() }
                Button("저장 폴더 열기") { appModel.openSaveFolder() }
                Divider()
                SettingsLink { Text("설정…") }
                Divider()
                Button("종료") { NSApplication.shared.terminate(nil) }
            } else {
                Button("이 맥은 데스크 뷰를 지원하지 않습니다") {}.disabled(true)
                Divider()
                Button("종료") { NSApplication.shared.terminate(nil) }
            }
        }

        Settings {
            if let settingsModel = appModel.settingsModel {
                SettingsView(model: settingsModel)
            } else {
                EmptyView()
            }
        }
    }
}

/// 지원 판별·권한·구성요소 조립을 담당하는 앱 모델.
@MainActor
final class AppModel: ObservableObject {
    @Published var isSupported = false
    @Published var cameraAuthorized = false

    private(set) var camera: CameraManager?
    private(set) var coordinator: CaptureCoordinator?
    private(set) var settingsModel: SettingsModel?
    private let hotkey = HotkeyManager()
    private let settings = SettingsStore(defaults: .standard)

    init() {
        detectSupport()
        guard isSupported else {
            presentUnsupportedAlert()
            return
        }

        let camera = CameraManager(rotationDegrees: settings.rotationDegrees)
        let coordinator = CaptureCoordinator(camera: camera, settings: settings)
        self.camera = camera
        self.coordinator = coordinator
        self.settingsModel = SettingsModel(store: settings)

        hotkey.register(settings.hotkey) { [weak coordinator] in
            Task { @MainActor in coordinator?.trigger() }
        }

        // 카메라는 권한이 확정된 뒤에만 시작한다. (미승인 상태로 세션을 켜면 프레임이 오지 않음)
        startCameraWhenAuthorized()

        // 실행 직후 미리보기를 자동으로 띄운다. (NSApp 기동 뒤로 미룬다)
        DispatchQueue.main.async { [weak self] in self?.showPreview() }
    }

    // 미리보기는 LSUIElement 앱에서 SwiftUI Window 씬이 자동으로 뜨지 않으므로
    // AppKit NSWindow로 직접 관리한다. 하나만 만들어 두고 재사용한다.
    private var previewWindow: NSWindow?

    /// 미리보기 창을 띄우거나(없으면 생성) 앞으로 가져온다. 카메라 세션도 시작한다.
    func showPreview() {
        guard isSupported, let camera else { return }
        if previewWindow == nil {
            let view = PreviewWindow(
                previewLayer: camera.previewLayer,
                onCapture: { [weak self] in self?.coordinator?.trigger() },
                onRotate: { [weak self] in self?.rotatePreview() },
                onAdjustArea: { [weak self] in self?.openDeskViewSetup() },
                onOpenFolder: { [weak self] in self?.openLastCaptureFolder() })
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 640, height: 520),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered, defer: false)
            window.title = "Table_shot 미리보기"
            window.contentView = NSHostingView(rootView: view)
            window.isReleasedWhenClosed = false
            window.center()
            previewWindow = window
        }
        camera.start()
        NSApp.activate(ignoringOtherApps: true)
        previewWindow?.makeKeyAndOrderFront(nil)
    }

    private func detectSupport() {
        let session = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.deskViewCamera],
            mediaType: .video,
            position: .unspecified)
        let typeIDs = session.devices.map { $0.deviceType.rawValue }
        isSupported = isDeskViewSupported(availableDeviceTypeIDs: typeIDs)
    }

    private func startCameraWhenAuthorized() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            cameraAuthorized = true
            camera?.start()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                Task { @MainActor in
                    self?.cameraAuthorized = granted
                    if granted { self?.camera?.start() }   // 승인 직후에 시작(재실행 불필요)
                }
            }
        default:
            cameraAuthorized = false
        }
    }

    private func presentUnsupportedAlert() {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "데스크 뷰를 사용할 수 없습니다"
            alert.informativeText = """
            Table_shot은 데스크 뷰(Desk View) 카메라가 있는 맥에서만 동작합니다.
            12MP 센터 스테이지 내장 카메라를 갖춘 M4 이상 맥북 에어/프로, iMac(2024)에서 사용하세요.
            """
            alert.alertStyle = .warning
            alert.addButton(withTitle: "종료")
            NSApp.activate(ignoringOtherApps: true)
            alert.runModal()
            NSApplication.shared.terminate(nil)
        }
    }

    func openCameraSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera") {
            NSWorkspace.shared.open(url)
        }
    }

    // 데스크 뷰 영역(사다리꼴)은 코드로 지정할 수 없다. 애플 데스크 뷰 앱의 설정 모드를
    // 띄워, 사용자가 책상 영역에 사다리꼴을 직접 맞추게 한다. (선택 영역은 시스템에 저장됨)
    private var deskViewApp: AVCaptureDeskViewApplication?

    /// "데스크 뷰 영역 맞추기": 애플 데스크 뷰 설정 모드를 연다.
    func openDeskViewSetup() {
        let app = AVCaptureDeskViewApplication()
        self.deskViewApp = app   // present가 비동기이므로 강한 참조를 유지한다.
        let config = AVCaptureDeskViewApplication.LaunchConfiguration()
        config.requiresSetUpModeCompletion = true
        NSApp.activate(ignoringOtherApps: true)
        app.present(launchConfiguration: config) { [weak self] error in
            Task { @MainActor in
                if let error {
                    self?.coordinator?.lastErrorMessage =
                        "데스크 뷰 설정을 열 수 없습니다: \(error.localizedDescription)"
                }
                self?.deskViewApp = nil
            }
        }
    }

    /// 미리보기 "회전" 버튼: 90°씩 돌려 설정에 저장하고, 미리보기·캡처에 즉시 반영한다.
    func rotatePreview() {
        let next = SettingsStore.normalizedRotation(settings.rotationDegrees + 90)
        settings.rotationDegrees = next
        camera?.applyRotation(next)
    }

    func openSaveFolder() {
        let url = settings.saveFolderURL
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        NSWorkspace.shared.open(url)
    }

    /// 미리보기 "폴더 열기": 방금 찍은 이미지가 든 (시각 이름의) 폴더에서 그 파일을 선택해 연다.
    /// 아직 캡처가 없으면 기본 저장 폴더를 연다.
    func openLastCaptureFolder() {
        if let last = coordinator?.lastSavedURL,
           FileManager.default.fileExists(atPath: last.path) {
            NSWorkspace.shared.activateFileViewerSelecting([last])
        } else {
            openSaveFolder()
        }
    }
}
