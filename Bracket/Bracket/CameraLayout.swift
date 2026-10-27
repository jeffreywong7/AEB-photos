import Foundation
import CoreGraphics

struct CameraLayout {
    let size: CGSize
    let safeTop: CGFloat
    let safeBottom: CGFloat

    var previewFrame: CGRect {
        let height = size.width * 4 / 3
        let top = max(0, size.height - safeBottom - 176 - height)
        return CGRect(x: 0, y: top, width: size.width, height: height)
    }

    var toolbarCenter: CGPoint {
        let y = previewFrame.minY >= safeTop + 44 ? previewFrame.minY - 36 : safeTop + 22
        return CGPoint(x: size.width / 2, y: y)
    }

    var footerCenter: CGPoint {
        CGPoint(x: size.width / 2, y: size.height - safeBottom - 24)
    }

    var shutterCenter: CGPoint {
        CGPoint(x: size.width / 2, y: min(previewFrame.maxY + 56, footerCenter.y - 76))
    }
}
