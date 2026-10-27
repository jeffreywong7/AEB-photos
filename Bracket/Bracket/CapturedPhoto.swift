import UIKit
import ImageIO
import UniformTypeIdentifiers

struct CapturedPhoto: Identifiable {
    let id = UUID()
    let data: Data
    let preview: UIImage
    let createdAt: Date?

    init?(data: Data, createdAt: Date? = nil) {
        guard let image = UIImage(data: data) else { return nil }
        self.data = data
        self.preview = image.preparingThumbnail(of: CGSize(width: 1600, height: 1600)) ?? image
        self.createdAt = createdAt ?? PhotoCaptureDate.read(from: data)
    }

    var image: UIImage { UIImage(data: data) ?? preview }

    var pixelDimensions: String {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int else { return "—" }
        let orientation = properties[kCGImagePropertyOrientation] as? Int ?? 1
        return (5...8).contains(orientation) ? "\(height) × \(width)" : "\(width) × \(height)"
    }

    private var contentType: UTType? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil), let type = CGImageSourceGetType(source) else { return nil }
        return UTType(type as String)
    }

    var formatName: String {
        guard let type = contentType else { return "Image" }
        switch type {
        case .jpeg: return "JPEG"
        case .heic, .heif: return "HEIF"
        default: return type.preferredFilenameExtension?.uppercased() ?? "Image"
        }
    }

    func prepareShareFile() throws -> URL {
        let suffix = contentType == .jpeg ? "jpg" : contentType?.preferredFilenameExtension ?? "img"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Bracket-\(UUID().uuidString).\(suffix)")
        try data.write(to: url, options: .atomic)
        return url
    }
}
