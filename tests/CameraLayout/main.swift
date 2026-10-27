import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

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
precondition(CameraLevelReading(gravityX: 0.1, gravityY: -0.995, gravityZ: 0, sampleAge: 0.1) == left, "Display a current gravity sample")
precondition(CameraLevelReading(gravityX: 0.1, gravityY: -0.995, gravityZ: 0, sampleAge: 1) == nil, "Do not leave a stale angle on screen")
precondition(CameraLevelReading(gravityX: 0.1, gravityY: -0.995, gravityZ: 0, sampleAge: -1) == nil, "Reject a sample with an invalid timestamp")
print("Camera level checks passed")

let portrait = CGSize(width: 2400, height: 3200)
precondition(PhotoAspect.standard.cropRect(in: portrait, rotated: false) == CGRect(origin: .zero, size: portrait))
precondition(PhotoAspect.square.cropRect(in: portrait, rotated: false) == CGRect(x: 0, y: 400, width: 2400, height: 2400))
precondition(PhotoAspect.wide.cropRect(in: portrait, rotated: false) == CGRect(x: 300, y: 0, width: 1800, height: 3200))
let landscape = CGSize(width: 3200, height: 2400)
precondition(PhotoAspect.wide.cropRect(in: landscape, rotated: true) == CGRect(x: 0, y: 300, width: 3200, height: 1800))
let wideLayout = CameraLayout(size: reference.size, safeTop: 59, safeBottom: 34, aspect: .wide)
near(wideLayout.previewFrame.width / wideLayout.previewFrame.height, 9.0 / 16.0, "Wide preview aspect")
precondition(wideLayout.shutterCenter == reference.shutterCenter, "Aspect selection must not move the shutter")
print("Aspect framing checks passed")

let context = CGContext(data: nil, width: 3200, height: 2400, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
context.setFillColor(CGColor(gray: 0.5, alpha: 1))
context.fill(CGRect(x: 0, y: 0, width: 3200, height: 2400))
let fixture = NSMutableData()
let destination = CGImageDestinationCreateWithData(fixture, UTType.jpeg.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(destination, context.makeImage()!, [kCGImagePropertyOrientation: 6,
    kCGImagePropertyExifDictionary: [kCGImagePropertyExifISOSpeedRatings: [100]]] as CFDictionary)
precondition(CGImageDestinationFinalize(destination))
let original = fixture as Data
let unchanged = try PhotoCrop.jpeg(original, aspect: .standard)
precondition(unchanged == original, "4:3 source JPEG bytes must remain unchanged")
let cropped = try PhotoCrop.jpeg(original, aspect: .wide)
let source = CGImageSourceCreateWithData(cropped as CFData, nil)!
let metadata = CGImageSourceCopyPropertiesAtIndex(source, 0, nil)! as! [CFString: Any]
precondition(metadata[kCGImagePropertyPixelWidth] as? Int == 3200)
precondition(metadata[kCGImagePropertyPixelHeight] as? Int == 1800)
precondition(metadata[kCGImagePropertyOrientation] as? Int == 6, "Preserve the camera JPEG's EXIF rotation")
let exif = metadata[kCGImagePropertyExifDictionary] as! [CFString: Any]
precondition((exif[kCGImagePropertyExifISOSpeedRatings] as? [Int]) == [100], "Preserve exposure metadata when cropping")
print("JPEG crop and orientation checks passed")

precondition(PhotoCaptureDate.read(from: original) == nil, "A missing EXIF capture date must stay unknown")
let datedJPEG = NSMutableData()
let datedDestination = CGImageDestinationCreateWithData(datedJPEG, UTType.jpeg.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(datedDestination, context.makeImage()!, [kCGImagePropertyExifDictionary:
    [kCGImagePropertyExifDateTimeOriginal: "2018:03:30 12:14:32"]] as CFDictionary)
precondition(CGImageDestinationFinalize(datedDestination))
let expectedDate = Calendar(identifier: .gregorian).date(from: DateComponents(year: 2018, month: 3, day: 30, hour: 12, minute: 14, second: 32))!
precondition(PhotoCaptureDate.read(from: datedJPEG as Data) == expectedDate, "Preserve a known EXIF capture date")
print("Capture date metadata checks passed")

let captureFolder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
defer { try? FileManager.default.removeItem(at: captureFolder) }
let captureURL = captureFolder.appendingPathComponent("Photos.plist")
let store = RecentCaptureStore(fileURL: captureURL)
let missing = try store.load()
precondition(missing.isEmpty, "A first launch must not require an existing capture")
let saved = [StoredCapturePhoto(data: original, createdAt: Date(timeIntervalSince1970: 1_793_052_060)),
             StoredCapturePhoto(data: cropped, createdAt: Date(timeIntervalSince1970: 1_793_052_061))]
try store.save(saved)
let restored = try RecentCaptureStore(fileURL: captureURL).load()
precondition(restored == saved, "A new store instance must restore every original byte and timestamp")
try store.save([saved[1]])
let replaced = try store.load()
precondition(replaced == [saved[1]], "A new capture replaces the previous bracket")
let undated = StoredCapturePhoto(data: original, createdAt: nil)
try store.save([undated])
let restoredUndated = try store.load()
precondition(restoredUndated == [undated], "Preserve an unknown date without inventing a timestamp")
let legacyRecords: [[String: Any]] = [["data": original, "createdAt": saved[0].createdAt!]]
let legacy = try PropertyListSerialization.data(fromPropertyList: legacyRecords, format: .binary, options: 0)
try legacy.write(to: captureURL, options: .atomic)
let restoredLegacy = try store.load()
precondition(restoredLegacy == [saved[0]], "Continue reading captures saved with the original required-date schema")
try Data("invalid property list".utf8).write(to: captureURL, options: .atomic)
do {
    _ = try store.load()
    preconditionFailure("Invalid stored data must report a restoration error")
} catch {}
print("Recent capture persistence checks passed")
