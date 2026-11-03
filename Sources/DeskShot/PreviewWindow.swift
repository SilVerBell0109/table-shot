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

    var body: some View {
        VStack(spacing: 0) {
            PreviewLayerView(previewLayer: previewLayer)
                .frame(minWidth: 480, minHeight: 320)
                .background(Color.black)
            Button(action: onCapture) {
                Label("찍기", systemImage: "camera.fill")
                    .font(.title2)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
            .keyboardShortcut(.defaultAction)
            .buttonStyle(.borderedProminent)
            .padding(12)
        }
        .frame(minWidth: 480, minHeight: 380)
    }
}
