import Foundation

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
