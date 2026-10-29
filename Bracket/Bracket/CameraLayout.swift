import Foundation
import CoreGraphics

struct CameraLayout {
    let size: CGSize
    let safeTop: CGFloat
    let safeBottom: CGFloat
    let aspect: PhotoAspect

    init(size: CGSize, safeTop: CGFloat, safeBottom: CGFloat, aspect: PhotoAspect = .standard) {
        self.size = size
        self.safeTop = safeTop
        self.safeBottom = safeBottom
        self.aspect = aspect
    }

    var controlsFrame: CGRect {
        let height = size.width * 4 / 3
        let top = max(0, size.height - safeBottom - 176 - height)
        return CGRect(x: 0, y: top, width: size.width, height: height)
    }

    var previewFrame: CGRect {
        let height = size.width / aspect.portraitRatio
        return CGRect(x: 0, y: controlsFrame.midY - height / 2, width: size.width, height: height)
    }

    var toolbarCenter: CGPoint {
        let y = controlsFrame.minY >= safeTop + 44 ? controlsFrame.minY - 36 : safeTop + 22
        return CGPoint(x: size.width / 2, y: y)
    }

    var footerCenter: CGPoint {
        CGPoint(x: size.width / 2, y: size.height - safeBottom - 24)
    }

    var shutterCenter: CGPoint {
        CGPoint(x: size.width / 2, y: min(controlsFrame.maxY + 56, footerCenter.y - 76))
    }
}
