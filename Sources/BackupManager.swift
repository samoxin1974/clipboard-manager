import Foundation

struct BackupPayload: Codable {
    let app: String
    let version: String
    let exportedAt: Date
    let items: [BackupItem]
    let snippets: [Snippet]
}

struct BackupItem: Codable {
    let id: String
    let createdAt: Date
    let kind: String
    let plainText: String?
    let htmlText: String?
    let imageBase64: String?
    let imageWidth: Int?
    let imageHeight: Int?
    let filePaths: [String]
    let colorHex: String?
    let sourceBundleID: String?
    let sourceName: String?
    let contentHash: String
    let pinned: Bool
    let ocrText: String?
    let byteSize: Int
    let searchText: String

    init(item: ClipItem, imageBase64: String?) {
        id = item.id
        createdAt = item.createdAt
        kind = item.kind.rawValue
        plainText = item.plainText
        htmlText = item.htmlText
        self.imageBase64 = imageBase64
        imageWidth = item.imageWidth
        imageHeight = item.imageHeight
        filePaths = item.filePaths
        colorHex = item.colorHex
        sourceBundleID = item.sourceBundleID
        sourceName = item.sourceName
        contentHash = item.contentHash
        pinned = item.pinned
        ocrText = item.ocrText
        byteSize = item.byteSize
        searchText = item.searchText
    }
}

enum BackupManager {
    static func exportData(items: [ClipItem], snippets: [Snippet], imageStore: ImageStore) throws -> Data {
        let backupItems = items.map { item -> BackupItem in
            var base64: String?
            if let fileName = item.imageFileName {
                let url = imageStore.fileURL(for: fileName)
                if let data = try? Data(contentsOf: url) {
                    base64 = data.base64EncodedString()
                }
            }
            return BackupItem(item: item, imageBase64: base64)
        }
        let payload = BackupPayload(
            app: "Clipboard Manager",
            version: AppInfo.version,
            exportedAt: Date(),
            items: backupItems,
            snippets: snippets
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(payload)
    }

    static func importData(
        _ data: Data,
        database: ClipboardDatabase,
        imageStore: ImageStore
    ) throws -> (items: Int, snippets: Int) {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let payload = try decoder.decode(BackupPayload.self, from: data)
        var itemCount = 0
        for backup in payload.items {
            guard let kind = ClipKind(rawValue: backup.kind) else { continue }
            var imageFileName: String?
            var width = backup.imageWidth
            var height = backup.imageHeight
            var hash = backup.contentHash
            if let base64 = backup.imageBase64, let imageData = Data(base64Encoded: base64) {
                hash = StableHash.data(imageData)
                if let stored = try? imageStore.save(data: imageData, hash: hash) {
                    imageFileName = stored.fileName
                    width = stored.width
                    height = stored.height
                }
            }
            let item = ClipItem(
                id: backup.id,
                createdAt: backup.createdAt,
                kind: kind,
                plainText: backup.plainText,
                htmlText: backup.htmlText,
                imageFileName: imageFileName,
                imageWidth: width,
                imageHeight: height,
                filePaths: backup.filePaths,
                colorHex: backup.colorHex,
                sourceBundleID: backup.sourceBundleID,
                sourceName: backup.sourceName,
                contentHash: hash,
                pinned: backup.pinned,
                ocrText: backup.ocrText,
                byteSize: backup.byteSize,
                searchText: backup.searchText
            )
            let result = try database.save(item)
            if result.inserted { itemCount += 1 }
        }
        var snippetCount = 0
        for snippet in payload.snippets {
            try database.saveSnippet(snippet)
            snippetCount += 1
        }
        return (itemCount, snippetCount)
    }
}
