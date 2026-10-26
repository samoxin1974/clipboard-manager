import Foundation
import Carbon.HIToolbox

enum ClipKind: String, Codable, CaseIterable, Hashable {
    case text
    case richText
    case link
    case image
    case file
    case color

    var title: String {
        switch self {
        case .text: return "Text"
        case .richText: return "Rich Text"
        case .link: return "Link"
        case .image: return "Image"
        case .file: return "File"
        case .color: return "Color"
        }
    }

    var symbolName: String {
        switch self {
        case .text: return "text.alignleft"
        case .richText: return "textformat"
        case .link: return "link"
        case .image: return "photo"
        case .file: return "doc"
        case .color: return "paintpalette"
        }
    }

    var isTextual: Bool {
        switch self {
        case .text, .richText, .link: return true
        default: return false
        }
    }
}

struct ClipItem: Identifiable, Codable, Hashable {
    var id: String
    var createdAt: Date
    var kind: ClipKind
    var plainText: String?
    var htmlText: String?
    var imageFileName: String?
    var imageWidth: Int?
    var imageHeight: Int?
    var filePaths: [String]
    var colorHex: String?
    var sourceBundleID: String?
    var sourceName: String?
    var contentHash: String
    var pinned: Bool
    var ocrText: String?
    var byteSize: Int
    var searchText: String

    init(
        id: String = UUID().uuidString,
        createdAt: Date = Date(),
        kind: ClipKind,
        plainText: String? = nil,
        htmlText: String? = nil,
        imageFileName: String? = nil,
        imageWidth: Int? = nil,
        imageHeight: Int? = nil,
        filePaths: [String] = [],
        colorHex: String? = nil,
        sourceBundleID: String? = nil,
        sourceName: String? = nil,
        contentHash: String,
        pinned: Bool = false,
        ocrText: String? = nil,
        byteSize: Int = 0,
        searchText: String = ""
    ) {
        self.id = id
        self.createdAt = createdAt
        self.kind = kind
        self.plainText = plainText
        self.htmlText = htmlText
        self.imageFileName = imageFileName
        self.imageWidth = imageWidth
        self.imageHeight = imageHeight
        self.filePaths = filePaths
        self.colorHex = colorHex
        self.sourceBundleID = sourceBundleID
        self.sourceName = sourceName
        self.contentHash = contentHash
        self.pinned = pinned
        self.ocrText = ocrText
        self.byteSize = byteSize
        self.searchText = searchText
    }

    var previewText: String {
        switch kind {
        case .text, .richText, .link:
            return (plainText ?? "").collapsedWhitespace.safePrefix(160)
        case .image:
            if let width = imageWidth, let height = imageHeight {
                return "Image \(width) × \(height)"
            }
            return "Image"
        case .file:
            let names = filePaths.map { URL(fileURLWithPath: $0).lastPathComponent }
            return names.joined(separator: ", ").safePrefix(160)
        case .color:
            return colorHex ?? "Color"
        }
    }

    var titleText: String {
        switch kind {
        case .text:
            let text = (plainText ?? "").trimmed
            if text.isCodeLike {
                return text.collapsedWhitespace.safePrefix(90)
            }
            let first = text.components(separatedBy: .newlines).first ?? ""
            return first.trimmed.isEmpty ? kind.title : first.trimmed.safePrefix(90)
        case .richText:
            let first = (plainText ?? "").trimmed.components(separatedBy: .newlines).first ?? ""
            return first.trimmed.isEmpty ? kind.title : first.trimmed.safePrefix(90)
        case .link:
            let text = (plainText ?? "").trimmed
            if let url = URL(string: URLTools.normalizedURLString(text)), let host = url.host {
                return host
            }
            return text.safePrefix(90)
        case .image:
            return "Image"
        case .file:
            return filePaths.first.map { URL(fileURLWithPath: $0).lastPathComponent } ?? "File"
        case .color:
            return colorHex ?? "Color"
        }
    }

    var listPreview: String {
        switch kind {
        case .text, .richText:
            let text = (plainText ?? "").trimmed
            if kind == .text, text.isCodeLike { return "" }
            let first = text.components(separatedBy: .newlines).first?.collapsedWhitespace ?? ""
            let all = text.collapsedWhitespace
            if !first.isEmpty, all.hasPrefix(first) {
                let rest = String(all.dropFirst(first.count)).trimmed
                return rest.safePrefix(160)
            }
            return all.safePrefix(160)
        case .link:
            let text = (plainText ?? "").trimmed
            return text == titleText ? "" : text
        case .image:
            if let width = imageWidth, let height = imageHeight {
                return "\(width) × \(height) pixels"
            }
            return "Image capture"
        case .file:
            if filePaths.count > 1 {
                return "\(filePaths.count) files selected"
            }
            guard let first = filePaths.first else { return "" }
            return URL(fileURLWithPath: first).deletingLastPathComponent().path
        case .color:
            return "Color swatch"
        }
    }

    var sourceDisplayName: String {
        if let name = sourceName, !name.isEmpty { return name }
        return "Unknown app"
    }

    var formattedDate: String {
        createdAt.relativeDescription
    }

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: Int64(byteSize), countStyle: .file)
    }

    var isOCRSearchable: Bool {
        guard kind == .image, let text = ocrText else { return false }
        return !text.trimmed.isEmpty
    }
}

struct Snippet: Identifiable, Codable, Hashable {
    var id: String
    var title: String
    var body: String
    var createdAt: Date
    var updatedAt: Date

    init(
        id: String = UUID().uuidString,
        title: String,
        body: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.body = body
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var previewText: String {
        body.collapsedWhitespace.safePrefix(120)
    }
}

struct GlobalShortcut: Codable, Equatable, Hashable {
    var keyCode: UInt32
    var carbonModifiers: UInt32
    var display: String

    static let defaultValue = GlobalShortcut(
        keyCode: 50,
        carbonModifiers: UInt32(controlKey),
        display: "⌃`"
    )
}

enum HistoryFilter: String, CaseIterable, Identifiable {
    case all
    case text
    case links
    case images
    case files
    case colors
    case pinned

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return "All Items"
        case .text: return "Text"
        case .links: return "Links"
        case .images: return "Images"
        case .files: return "Files"
        case .colors: return "Colors"
        case .pinned: return "Pinned"
        }
    }

    var symbolName: String {
        switch self {
        case .all: return "square.grid.2x2"
        case .text: return "text.alignleft"
        case .links: return "link"
        case .images: return "photo"
        case .files: return "doc"
        case .colors: return "paintpalette"
        case .pinned: return "pin"
        }
    }

    func matches(_ item: ClipItem) -> Bool {
        switch self {
        case .all: return true
        case .text: return item.kind == .text || item.kind == .richText
        case .links: return item.kind == .link
        case .images: return item.kind == .image
        case .files: return item.kind == .file
        case .colors: return item.kind == .color
        case .pinned: return item.pinned
        }
    }
}

enum PanelMode: String, CaseIterable, Identifiable {
    case history
    case snippets

    var id: String { rawValue }

    var title: String {
        switch self {
        case .history: return "History"
        case .snippets: return "Snippets"
        }
    }

    var symbolName: String {
        switch self {
        case .history: return "clock"
        case .snippets: return "text.badge.plus"
        }
    }
}

enum PasteVariant: String, CaseIterable, Identifiable {
    case normal
    case plainText
    case uppercase
    case lowercase
    case titleCase
    case trimmed
    case jsonPretty
    case jsonMinified
    case urlEncoded
    case urlDecoded
    case base64Encoded
    case base64Decoded

    var id: String { rawValue }

    var title: String {
        switch self {
        case .normal: return "Paste"
        case .plainText: return "Paste as Plain Text"
        case .uppercase: return "Paste as UPPERCASE"
        case .lowercase: return "Paste as lowercase"
        case .titleCase: return "Paste as Title Case"
        case .trimmed: return "Paste Trimmed"
        case .jsonPretty: return "Paste Pretty JSON"
        case .jsonMinified: return "Paste Minified JSON"
        case .urlEncoded: return "Paste URL Encoded"
        case .urlDecoded: return "Paste URL Decoded"
        case .base64Encoded: return "Paste Base64 Encoded"
        case .base64Decoded: return "Paste Base64 Decoded"
        }
    }

    var transformTitle: String {
        switch self {
        case .normal: return "Original"
        case .plainText: return "Plain Text"
        case .uppercase: return "Uppercase"
        case .lowercase: return "Lowercase"
        case .titleCase: return "Title Case"
        case .trimmed: return "Trim Whitespace"
        case .jsonPretty: return "Pretty JSON"
        case .jsonMinified: return "Minify JSON"
        case .urlEncoded: return "URL Encode"
        case .urlDecoded: return "URL Decode"
        case .base64Encoded: return "Base64 Encode"
        case .base64Decoded: return "Base64 Decode"
        }
    }

    var isTransform: Bool {
        switch self {
        case .normal, .plainText: return false
        default: return true
        }
    }

    func apply(to text: String) -> String? {
        switch self {
        case .normal, .plainText:
            return text
        case .uppercase:
            return text.uppercased()
        case .lowercase:
            return text.lowercased()
        case .titleCase:
            return text.titleCased
        case .trimmed:
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        case .jsonPretty:
            return JSONTools.formatted(text, pretty: true)
        case .jsonMinified:
            return JSONTools.formatted(text, pretty: false)
        case .urlEncoded:
            return text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
        case .urlDecoded:
            return text.removingPercentEncoding
        case .base64Encoded:
            return Data(text.utf8).base64EncodedString()
        case .base64Decoded:
            guard let data = Data(base64Encoded: text.trimmingCharacters(in: .whitespacesAndNewlines)) else { return nil }
            return String(data: data, encoding: .utf8)
        }
    }
}
