import XCTest
@testable import DeskShotKit

final class DeskViewSupportTests: XCTestCase {
    func test_supported_whenDeskViewTypePresent() {
        XCTAssertTrue(isDeskViewSupported(availableDeviceTypeIDs: [
            "AVCaptureDeviceTypeBuiltInWideAngleCamera",
            "AVCaptureDeviceTypeDeskViewCamera"]))
    }

    func test_unsupported_whenAbsent() {
        XCTAssertFalse(isDeskViewSupported(availableDeviceTypeIDs: [
            "AVCaptureDeviceTypeBuiltInWideAngleCamera"]))
    }
}
