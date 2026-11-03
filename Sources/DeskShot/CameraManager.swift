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

    /// 미리보기·캡처 프레임에 적용 중인 회전각(도).
    private var rotationDegrees: Int

    init(rotationDegrees: Int = 0) {
        self.rotationDegrees = rotationDegrees
        previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspect
        super.init()
        configure()
        applyRotation(rotationDegrees)
    }

    private func configure() {
        session.beginConfiguration()

        if let device = Self.selectCamera() {
            if let input = try? AVCaptureDeviceInput(device: device),
               session.canAddInput(input) {
                session.addInput(input)
            }
            // 데스크 뷰는 보통 1920x1440 단일 포맷이지만, 프리셋이 더 낮은 해상도로
            // 떨어뜨리지 않도록 최고 해상도 포맷을 명시적으로 고정한다. (가독성=해상도)
            if let best = device.formats.max(by: { Self.pixelCount($0) < Self.pixelCount($1) }),
               (try? device.lockForConfiguration()) != nil {
                device.activeFormat = best
                device.unlockForConfiguration()
            }
        }
        // activeFormat을 직접 지정하면 세션 프리셋이 자동으로 InputPriority가 되어
        // 그 포맷(최고 해상도)을 그대로 존중한다. 따로 sessionPreset을 줄 필요가 없다.

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

    /// 캡처에 쓸 내장 카메라. 책상을 담을 수 있는 건 데스크 뷰뿐이라 기본은 데스크 뷰다.
    /// (내장 광각은 사용자 얼굴을 향하는 웹캠이라 책상을 못 본다.)
    /// 데스크 뷰 프레임은 가공 없이 전체를 그대로 저장한다. (사용자 선택: 전체 프레임 유지)
    /// 환경변수 DESKSHOT_WIDE=1 이면 (진단용) 원본 광각 카메라를 쓴다.
    private static func selectCamera() -> AVCaptureDevice? {
        let wide = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera], mediaType: .video, position: .unspecified)
        if ProcessInfo.processInfo.environment["DESKSHOT_WIDE"] == "1" {
            return wide.devices.first
        }
        if let companion = wide.devices.first?.companionDeskViewCamera { return companion }
        return AVCaptureDevice.DiscoverySession(
            deviceTypes: [.deskViewCamera], mediaType: .video, position: .unspecified).devices.first
    }

    private static func pixelCount(_ format: AVCaptureDevice.Format) -> Int {
        let d = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
        return Int(d.width) * Int(d.height)
    }

    func start() {
        guard !session.isRunning else { return }
        sampleQueue.async { [weak self] in self?.session.startRunning() }
        // 세션 시작 시점에 연결이 다시 만들어질 수 있으므로 회전을 재적용한다.
        applyRotation(rotationDegrees)
    }

    /// 미리보기 레이어와 캡처 출력 양쪽 연결에 회전을 적용한다.
    /// 둘을 함께 돌려야 화면과 저장되는 PNG가 같은 방향이 된다.
    func applyRotation(_ degrees: Int) {
        rotationDegrees = degrees
        let angle = CGFloat(degrees)
        for connection in [previewLayer.connection, output.connection(with: .video)] {
            guard let connection else { continue }
            if connection.isVideoRotationAngleSupported(angle) {
                connection.videoRotationAngle = angle
            }
        }
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
