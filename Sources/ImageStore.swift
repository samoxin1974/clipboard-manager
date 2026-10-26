import Foundation
import AppKit

final class ImageStore {
    let directory: URL
    private let cache = NSCache<NSString, NSImage>()

    init(directory: URL) {
        self.directory = directory
        cache.countLimit = 120
    }

    func fileURL(for fileName: String) -> URL {
        directory.appendingPathComponent(fileName)
    }

    func save(data: Data, hash: String) throws -> (fileName: String, width: Int, height: Int) {
        guard data.count <= 30 * 1024 * 1024 else {
            throw ImageStoreError.tooLarge
        }
        guard let image = NSImage(data: data) else {
            throw ImageStoreError.invalidImage
        }
        let dimensions = image.pixelDimensions
        let fileName = "\(hash.safePrefix(40)).png"
        let url = fileURL(for: fileName)
        if FileManager.default.fileExists(atPath: url.path) {
            return (fileName, dimensions.width, dimensions.height)
        }
        let png: Data
        if data.starts(with: [0x89, 0x50, 0x4e, 0x47]) {
            png = data
        } else {
            guard let converted = image.pngData else { throw ImageStoreError.encodingFailed }
            png = converted
        }
        try png.write(to: url, options: .atomic)
        cache.setObject(image, forKey: fileName as NSString)
        return (fileName, dimensions.width, dimensions.height)
    }

    func image(named fileName: String) -> NSImage? {
        if let cached = cache.object(forKey: fileName as NSString) {
            return cached
        }
        let url = fileURL(for: fileName)
        guard let image = NSImage(contentsOf: url) else { return nil }
        cache.setObject(image, forKey: fileName as NSString)
        return image
    }

    func delete(fileNames: [String]) {
        for fileName in Set(fileNames) where !fileName.isEmpty {
            cache.removeObject(forKey: fileName as NSString)
            try? FileManager.default.removeItem(at: fileURL(for: fileName))
        }
    }

    func deleteAll() throws {
        cache.removeAllObjects()
        guard FileManager.default.fileExists(atPath: directory.path) else { return }
        let contents = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        for url in contents {
            try? FileManager.default.removeItem(at: url)
        }
    }

    func totalBytes() -> Int64 {
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.fileSizeKey]
        ) else { return 0 }
        return contents.reduce(into: Int64(0)) { total, url in
            let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            total += Int64(size)
        }
    }
}

enum ImageStoreError: LocalizedError {
    case tooLarge
    case invalidImage
    case encodingFailed

    var errorDescription: String? {
        switch self {
        case .tooLarge: return "Image is larger than 30 MB and was skipped."
        case .invalidImage: return "The image data could not be read."
        case .encodingFailed: return "The image could not be converted to PNG."
        }
    }
}
