import SwiftUI
import AVFoundation
import DeskShotKit

@main
struct DeskShotApp: App {
    @StateObject private var appModel = AppModel()
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        MenuBarExtra("DeskShot", systemImage: "camera.viewfinder") {
            if appModel.isSupported {
                if !appModel.cameraAuthorized {
                    Button("카메라 권한이 필요합니다 — 시스템 설정 열기") { appModel.openCameraSettings() }
                    Divider()
                }
                Button("찍기") { appModel.coordinator?.trigger() }
                    .keyboardShortcut("2", modifiers: [.command, .shift])
                Button("미리보기 열기") { activate(); openWindow(id: "preview") }
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

        Window("DeskShot 미리보기", id: "preview") {
            if appModel.isSupported, let camera = appModel.camera {
                PreviewWindow(
                    previewLayer: camera.previewLayer,
                    onCapture: { appModel.coordinator?.trigger() })
                .onAppear { camera.start() }
            }
        }
        .windowResizability(.contentMinSize)

        Settings {
            if let settingsModel = appModel.settingsModel {
                SettingsView(model: settingsModel)
            } else {
                EmptyView()
            }
        }
    }

    /// LSUIElement 앱은 openWindow만으로 앞으로 오지 않으므로 명시적으로 활성화한다.
    private func activate() {
        NSApp.activate(ignoringOtherApps: true)
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

        let camera = CameraManager()
        let coordinator = CaptureCoordinator(camera: camera, settings: settings)
        self.camera = camera
        self.coordinator = coordinator
        self.settingsModel = SettingsModel(store: settings)

        hotkey.register(settings.hotkey) { [weak coordinator] in
            Task { @MainActor in coordinator?.trigger() }
        }

        // 카메라는 권한이 확정된 뒤에만 시작한다. (미승인 상태로 세션을 켜면 프레임이 오지 않음)
        startCameraWhenAuthorized()
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
            DeskShot은 데스크 뷰(Desk View) 카메라가 있는 맥에서만 동작합니다.
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

    func openSaveFolder() {
        let url = settings.saveFolderURL
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        NSWorkspace.shared.open(url)
    }
}
