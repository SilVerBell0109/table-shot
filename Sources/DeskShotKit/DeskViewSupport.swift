import AVFoundation

/// 내장 데스크 뷰 카메라 장치 타입의 식별자 ("AVCaptureDeviceTypeDeskViewCamera").
public let deskViewCameraTypeID = AVCaptureDevice.DeviceType.deskViewCamera.rawValue

/// 사용 가능한 카메라 장치 타입 ID 목록에 데스크 뷰 카메라가 있으면 지원으로 판단한다.
/// (모델명 하드코딩 대신 런타임 장치 탐지로 판별하기 위한 순수 함수)
public func isDeskViewSupported(availableDeviceTypeIDs: [String]) -> Bool {
    availableDeviceTypeIDs.contains(deskViewCameraTypeID)
}
