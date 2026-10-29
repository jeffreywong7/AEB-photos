import Foundation
import CoreGraphics

enum PhotoAspect: String, CaseIterable {
    case standard = "4:3"
    case square = "1:1"
    case wide = "16:9"

    var portraitRatio: CGFloat {
        switch self {
        case .standard: return 3 / 4
        case .square: return 1
        case .wide: return 9 / 16
        }
    }

    func cropRect(in pixels: CGSize, rotated: Bool) -> CGRect {
        let ratio = rotated ? 1 / portraitRatio : portraitRatio
        if abs(pixels.width / pixels.height - ratio) < 0.000001 { return CGRect(origin: .zero, size: pixels) }
        let width = min(pixels.width, floor(pixels.height * ratio))
        let height = min(pixels.height, floor(pixels.width / ratio))
        return CGRect(x: floor((pixels.width - width) / 2), y: floor((pixels.height - height) / 2), width: width, height: height)
    }
}
