import Foundation

struct StoredCapturePhoto: Codable, Equatable {
    let data: Data
    let createdAt: Date
}

struct RecentCaptureStore {
    let fileURL: URL

    init(fileURL: URL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("RecentCapture/Photos.plist")) {
        self.fileURL = fileURL
    }

    func load() throws -> [StoredCapturePhoto] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return [] }
        return try PropertyListDecoder().decode([StoredCapturePhoto].self, from: Data(contentsOf: fileURL))
    }

    func save(_ photos: [StoredCapturePhoto]) throws {
        var directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try directory.setResourceValues(values)
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary
        try encoder.encode(photos).write(to: fileURL, options: .atomic)
    }
}
