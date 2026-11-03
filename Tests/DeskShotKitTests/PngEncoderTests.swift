import XCTest
import CoreGraphics
@testable import DeskShotKit

final class PngEncoderTests: XCTestCase {
    private func make1x1CGImage() -> CGImage {
        let cs = CGColorSpaceCreateDeviceRGB()
        let ctx = CGContext(
            data: nil, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
            space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
        return ctx.makeImage()!
    }

    func test_encode_producesPngSignature() {
        let data = PngEncoder.encode(make1x1CGImage())
        XCTAssertNotNil(data)
        XCTAssertEqual(Array(data!.prefix(4)), [0x89, 0x50, 0x4E, 0x47]) // \x89PNG
    }
}
