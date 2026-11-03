import AVFoundation
import CoreImage
import CoreGraphics
import QuartzCore

/// 데스크 뷰 카메라 세션을 관리한다. 미리보기 레이어 + 최신 프레임(CGImage) 공급.
final class CameraManager: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    let previewLayer: AVCaptureVideoPreviewLayer

    private let session = AVCaptureSession()
    private let output = AVCaptureVideoDataOutput()
    private let sampleQueue = DispatchQueue(label: "com.silverbell.deskshot.samples")
    private let ciContext = CIContext()

    // 최신 프레임은 락으로 보호한다. 오래된 프레임을 캡처하지 않도록 수신 시각도 함께 보관.
    private let frameLock = NSLock()
    private var latestPixelBuffer: CVPixelBuffer?
    private var latestFrameTime: CFTimeInterval = 0
    /// 이보다 오래된 프레임은 유효하지 않은 것으로 간주한다. (세션 중단/정지 대비)
    private let maxFrameAge: CFTimeInterval = 2.0

    override init() {
        previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspect
        super.init()
        configure()
    }

    private func configure() {
        session.beginConfiguration()
        session.sessionPreset = .photo

        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.deskViewCamera],
            mediaType: .video,
            position: .unspecified)
        if let device = discovery.devices.first,
           let input = try? AVCaptureDeviceInput(device: device),
           session.canAddInput(input) {
            session.addInput(input)
        }

        output.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(self, queue: sampleQueue)
        if session.canAddOutput(output) {
            session.addOutput(output)
        }

        session.commitConfiguration()
    }

    func start() {
        guard !session.isRunning else { return }
        sampleQueue.async { [weak self] in self?.session.startRunning() }
    }

    func stop() {
        guard session.isRunning else { return }
        sampleQueue.async { [weak self] in self?.session.stopRunning() }
        // 정지 후에는 남아 있는 프레임을 무효화한다.
        frameLock.lock()
        latestPixelBuffer = nil
        latestFrameTime = 0
        frameLock.unlock()
    }

    /// 가장 최근 프레임을 CGImage로 변환해 반환한다. 없거나 너무 오래됐으면 nil.
    func latestFrame() -> CGImage? {
        frameLock.lock()
        let buffer = latestPixelBuffer
        let age = CACurrentMediaTime() - latestFrameTime
        frameLock.unlock()
        guard let buffer, age <= maxFrameAge else { return nil }
        let ciImage = CIImage(cvPixelBuffer: buffer)
        let cs = CGColorSpace(name: CGColorSpace.sRGB)
        return ciContext.createCGImage(ciImage, from: ciImage.extent,
                                       format: .RGBA8, colorSpace: cs)
    }

    // MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        guard let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        frameLock.lock()
        latestPixelBuffer = buffer
        latestFrameTime = CACurrentMediaTime()
        frameLock.unlock()
    }
}
