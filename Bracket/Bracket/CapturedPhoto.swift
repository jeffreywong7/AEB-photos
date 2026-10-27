import UIKit
import ImageIO

struct CapturedPhoto: Identifiable {
    let id = UUID()
    let data: Data
    let preview: UIImage
    let createdAt: Date

    init?(data: Data, createdAt: Date = Date()) {
        guard let image = UIImage(data: data) else { return nil }
        self.data = data
        self.preview = image.preparingThumbnail(of: CGSize(width: 1600, height: 1600)) ?? image
        self.createdAt = createdAt
    }

    var image: UIImage { UIImage(data: data) ?? preview }

    var pixelDimensions: String {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int else { return "—" }
        return "\(width) × \(height)"
    }

    func prepareShareFile() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Bracket-\(UUID().uuidString).jpg")
        try data.write(to: url, options: .atomic)
        return url
    }
}
