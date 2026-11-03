import SwiftUI
import AVFoundation

/// AVCaptureVideoPreviewLayer를 SwiftUI에 끼워 넣는 래퍼.
struct PreviewLayerView: NSViewRepresentable {
    let previewLayer: AVCaptureVideoPreviewLayer

    func makeNSView(context: Context) -> NSView {
        let view = LayerHostView()
        view.wantsLayer = true
        view.hostedLayer = previewLayer
        previewLayer.frame = view.bounds
        view.layer?.addSublayer(previewLayer)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        previewLayer.frame = nsView.bounds
    }

    /// 레이어가 리사이즈를 따라가도록 하는 호스트 뷰.
    final class LayerHostView: NSView {
        weak var hostedLayer: CALayer?
        override func layout() {
            super.layout()
            hostedLayer?.frame = bounds
        }
    }
}

/// 라이브 미리보기 + 큰 "찍기" 버튼.
struct PreviewWindow: View {
    let previewLayer: AVCaptureVideoPreviewLayer
    let onCapture: () -> Void
    let onRotate: () -> Void
    let onAdjustArea: () -> Void
    let onOpenFolder: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            PreviewLayerView(previewLayer: previewLayer)
                .frame(minWidth: 480, minHeight: 320)
                .background(Color.black)
            HStack(spacing: 10) {
                Button(action: onCapture) {
                    Label("찍기", systemImage: "camera.fill")
                        .font(.title2)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)

                Button(action: onAdjustArea) {
                    Label("영역 맞추기", systemImage: "crop")
                        .font(.title2)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 6)
                }
                .buttonStyle(.bordered)
                .help("책상이 제대로 안 잡히면 눌러 데스크 뷰 설정을 열고, 사다리꼴을 책상 영역에 맞추세요")

                Button(action: onRotate) {
                    Label("회전", systemImage: "rotate.right")
                        .font(.title2)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 6)
                }
                .buttonStyle(.bordered)
                .help("화면이 뒤집혀 보이면 눌러서 90°씩 돌리세요 (설정에 저장됩니다)")

                Button(action: onOpenFolder) {
                    Label("폴더 열기", systemImage: "folder")
                        .font(.title2)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 6)
                }
                .buttonStyle(.bordered)
                .help("방금 찍은 이미지가 들어 있는 폴더를 Finder에서 엽니다")
            }
            .padding(12)
        }
        .frame(minWidth: 540, minHeight: 380)
    }
}
