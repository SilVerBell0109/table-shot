import SwiftUI
import AVFoundation
import DeskShotKit

@main
struct DeskShotApp: App {
    @StateObject private var appModel = AppModel()

    var body: some Scene {
        MenuBarExtra("DeskShot", systemImage: "camera.viewfinder") {
            if appModel.isSupported {
                SupportedMenu(appModel: appModel)
            } else {
                Button("이 맥은 데스크 뷰를 지원하지 않습니다") {}
                    .disabled(true)
                Divider()
                Button("종료") { NSApplication.shared.terminate(nil) }
            }
        }

        // 미지원 안내 창(지원되지 않을 때만 자동 표시)
        Window("DeskShot", id: "unsupported") {
            if !appModel.isSupported {
                UnsupportedView()
            }
        }
    }
}

/// 지원 여부·권한 상태를 들고 있는 앱 수준 모델.
@MainActor
final class AppModel: ObservableObject {
    @Published var isSupported: Bool = false
    @Published var cameraAuthorized: Bool = false

    init() {
        detectSupport()
        if isSupported { requestCameraAccess() }
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
}

/// 지원 맥에서의 메뉴바 메뉴. (트리거 배선은 Task 7에서 채운다)
struct SupportedMenu: View {
    @ObservedObject var appModel: AppModel

    var body: some View {
        if !appModel.cameraAuthorized {
            Button("카메라 권한이 필요합니다 — 시스템 설정 열기") {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera") {
                    NSWorkspace.shared.open(url)
                }
            }
            Divider()
        }
        Button("종료") { NSApplication.shared.terminate(nil) }
    }
}
