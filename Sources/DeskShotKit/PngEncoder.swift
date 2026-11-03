import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

/// CGImage를 PNG 데이터로 인코딩한다. 실패 시 nil.
public enum PngEncoder {
    public static func encode(_ image: CGImage) -> Data? {
        let data = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(
            data as CFMutableData, UTType.png.identifier as CFString, 1, nil) else {
            return nil
        }
        CGImageDestinationAddImage(dest, image, nil)
        guard CGImageDestinationFinalize(dest) else { return nil }
        return data as Data
    }
}
