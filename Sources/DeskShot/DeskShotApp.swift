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
                Button("미리보기 열기") { openWindow(id: "preview") }
                Button("저장 폴더 열기") { appModel.openSaveFolder() }
                Divider()
                Button("설정…") { openWindow(id: "settings") }
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

        Window("DeskShot 설정", id: "settings") {
            if let settingsModel = appModel.settingsModel {
                SettingsView(model: settingsModel)
            }
        }
        .windowResizability(.contentSize)

        Window("DeskShot", id: "unsupported") {
            if !appModel.isSupported {
                UnsupportedView()
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
        guard isSupported else { return }
        requestCameraAccess()

        let camera = CameraManager()
        let coordinator = CaptureCoordinator(camera: camera, settings: settings)
        self.camera = camera
        self.coordinator = coordinator
        self.settingsModel = SettingsModel(store: settings)

        camera.start()
        hotkey.register(settings.hotkey) { [weak coordinator] in
            Task { @MainActor in coordinator?.trigger() }
        }
    }

    private func detectSupport() {
        let session = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.deskViewCamera],
            mediaType: .video,
            position: .unspecified)
        let typeIDs = session.devices.map { $0.deviceType.rawValue }
        isSupported = isDeskViewSupported(availableDeviceTypeIDs: typeIDs)
    }

    private func requestCameraAccess() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            cameraAuthorized = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                Task { @MainActor in self?.cameraAuthorized = granted }
            }
        default:
            cameraAuthorized = false
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
