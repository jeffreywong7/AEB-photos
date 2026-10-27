import Foundation
import ImageIO
import UniformTypeIdentifiers

struct PhotoCrop {
    enum CropError: LocalizedError {
        case invalidImage
        case encodingFailed
        var errorDescription: String? { "Could not apply the selected photo aspect ratio. Please try again." }
    }

    static func jpeg(_ data: Data, aspect: PhotoAspect) throws -> Data {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              var properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int,
              width > 0, height > 0 else { throw CropError.invalidImage }
        let orientation = properties[kCGImagePropertyOrientation] as? Int ?? 1
        let pixels = CGSize(width: CGFloat(width), height: CGFloat(height))
        let rect = aspect.cropRect(in: pixels, rotated: (5...8).contains(orientation))
        if rect == CGRect(origin: .zero, size: pixels) { return data }
        guard let image = CGImageSourceCreateImageAtIndex(source, 0, nil), let cropped = image.cropping(to: rect) else {
            throw CropError.invalidImage
        }
        let result = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(result, UTType.jpeg.identifier as CFString, 1, nil) else {
            throw CropError.encodingFailed
        }
        properties[kCGImagePropertyPixelWidth] = cropped.width
        properties[kCGImagePropertyPixelHeight] = cropped.height
        if var exif = properties[kCGImagePropertyExifDictionary] as? [CFString: Any] {
            exif[kCGImagePropertyExifPixelXDimension] = cropped.width
            exif[kCGImagePropertyExifPixelYDimension] = cropped.height
            properties[kCGImagePropertyExifDictionary] = exif
        }
        properties[kCGImageDestinationLossyCompressionQuality] = 1.0
        CGImageDestinationAddImage(destination, cropped, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw CropError.encodingFailed }
        return result as Data
    }
}
