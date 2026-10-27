import Foundation
import CoreGraphics

func near(_ actual: CGFloat, _ expected: CGFloat, _ description: String) {
    precondition(abs(actual - expected) <= 0.5, "\(description): expected \(expected), got \(actual)")
}

// The supplied 923×2000 Camera screenshots scaled to the 393×852 iPhone 15 Pro screen.
let reference = CameraLayout(size: CGSize(width: 393, height: 852), safeTop: 59, safeBottom: 34)
near(reference.previewFrame.minY, 118, "Viewfinder top")
near(reference.previewFrame.height, 524, "4:3 viewfinder height")
near(reference.toolbarCenter.y, 82, "Toolbar center")
near(reference.shutterCenter.y, 698, "Shutter center")
near(reference.footerCenter.y, 794, "Photo mode and camera-switch row")

for (width, height, top, bottom) in [(375.0, 667.0, 0.0, 0.0), (375, 812, 50, 34), (393, 852, 59, 34), (430, 932, 59, 34)] {
    let layout = CameraLayout(size: CGSize(width: width, height: height), safeTop: top, safeBottom: bottom)
    precondition(abs(layout.previewFrame.height / layout.previewFrame.width - 4.0 / 3.0) < 0.0001, "Preview must preserve 4:3 capture framing")
    precondition(layout.shutterCenter.y - 41 >= layout.previewFrame.maxY, "Shutter overlaps the captured frame")
    precondition(layout.footerCenter.y + 24 <= height - bottom, "Footer clips into the home indicator")
    precondition(layout.shutterCenter.y + 41 < layout.footerCenter.y - 24, "Shutter and footer overlap")
}
print("Camera layout checks passed")

let level = CameraLevelReading(gravityX: 0, gravityY: -1, gravityZ: 0)
precondition(level?.isLevel == true, "An upright, straight camera must be level")
let left = CameraLevelReading(gravityX: 0.1, gravityY: -0.995, gravityZ: 0)
let right = CameraLevelReading(gravityX: -0.1, gravityY: -0.995, gravityZ: 0)
precondition(left != nil && right != nil && left?.isLevel == false, "Small tilts must show an unaligned horizon")
precondition(abs(left!.angle + right!.angle) < 0.0001, "Opposite tilts must rotate the level in opposite directions")
precondition(CameraLevelReading(gravityX: 0, gravityY: 0, gravityZ: -1) == nil, "Do not show an upright horizon when pointing down")
precondition(CameraLevelReading(gravityX: 0.7, gravityY: -0.7, gravityZ: 0) == nil, "Hide the fine level for large camera rolls")
print("Camera level checks passed")
