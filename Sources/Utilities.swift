import Foundation
import AppKit
import CryptoKit
import Carbon.HIToolbox

enum AppLog {
    static var fileURL: URL?
    private static let queue = DispatchQueue(label: "local.clipboardmanager.pro.log")

    static func write(_ message: String) {
        guard let url = fileURL else { return }
        let stamp = ISO8601DateFormatter().string(from: Date())
        let line = "\(stamp) \(message)\n"
        queue.async {
            if !FileManager.default.fileExists(atPath: url.path) {
                try? FileManager.default.createDirectory(
                    at: url.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                FileManager.default.createFile(atPath: url.path, contents: nil)
            }
            guard let handle = try? FileHandle(forWritingTo: url) else { return }
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: Data(line.utf8))
        }
    }
}

enum StableHash {
    static func string(_ value: String) -> String {
        let digest = SHA256.hash(data: Data(value.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    static func data(_ value: Data) -> String {
        let digest = SHA256.hash(data: value)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

enum JSONTools {
    static func formatted(_ text: String, pretty: Bool) -> String? {
        guard let data = text.data(using: .utf8) else { return nil }
        guard let object = try? JSONSerialization.jsonObject(with: data) else { return nil }
        var options: JSONSerialization.WritingOptions = [.fragmentsAllowed]
        if pretty {
            options.insert(.prettyPrinted)
            options.insert(.sortedKeys)
            options.insert(.withoutEscapingSlashes)
        } else {
            options.insert(.withoutEscapingSlashes)
        }
        guard let output = try? JSONSerialization.data(withJSONObject: object, options: options) else { return nil }
        return String(data: output, encoding: .utf8)
    }
}

enum HTMLTools {
    static func plainText(from html: String) -> String {
        guard let data = html.data(using: .utf8) else { return "" }
        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue
        ]
        guard let attributed = try? NSAttributedString(data: data, options: options, documentAttributes: nil) else {
            return ""
        }
        return attributed.string
    }

    static func html(fromRTF data: Data) -> String? {
        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.rtf
        ]
        guard let attributed = try? NSAttributedString(data: data, options: options, documentAttributes: nil) else {
            return nil
        }
        let range = NSRange(location: 0, length: attributed.length)
        guard let htmlData = try? attributed.data(
            from: range,
            documentAttributes: [.documentType: NSAttributedString.DocumentType.html]
        ) else {
            return nil
        }
        return String(data: htmlData, encoding: .utf8)
    }

    static func plainText(fromRTF data: Data) -> String? {
        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.rtf
        ]
        return try? NSAttributedString(data: data, options: options, documentAttributes: nil).string
    }

    static func attributedString(fromHTML html: String) -> NSAttributedString? {
        guard let data = html.data(using: .utf8) else { return nil }
        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue
        ]
        return try? NSAttributedString(data: data, options: options, documentAttributes: nil)
    }
}

enum URLTools {
    static func isLikelyURL(_ value: String) -> Bool {
        let text = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !text.contains(where: { $0.isWhitespace }) else { return false }
        if text.hasPrefix("www.") { return true }
        if let url = URL(string: text), let scheme = url.scheme, !scheme.isEmpty {
            return true
        }
        if let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) {
            let range = NSRange(location: 0, length: (text as NSString).length)
            let matches = detector.matches(in: text, options: [], range: range)
            return matches.count == 1 && matches[0].range == range
        }
        return false
    }

    static func normalizedURLString(_ value: String) -> String {
        let text = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasPrefix("www.") { return "https://\(text)" }
        return text
    }
}

enum SearchTextBuilder {
    static func build(
        kind: ClipKind,
        plainText: String?,
        htmlText: String?,
        filePaths: [String],
        colorHex: String?,
        sourceName: String?,
        ocrText: String?
    ) -> String {
        var parts: [String] = [kind.title]
        if let plainText, !plainText.isEmpty {
            parts.append(plainText)
        }
        if let htmlText, !htmlText.isEmpty {
            let stripped = HTMLTools.plainText(from: htmlText)
            if !stripped.isEmpty, stripped != plainText {
                parts.append(stripped)
            }
        }
        parts.append(contentsOf: filePaths.map { URL(fileURLWithPath: $0).lastPathComponent })
        parts.append(contentsOf: filePaths)
        if let colorHex {
            parts.append(colorHex)
        }
        if let sourceName, !sourceName.isEmpty {
            parts.append(sourceName)
        }
        if let ocrText, !ocrText.isEmpty {
            parts.append(ocrText)
        }
        return parts.joined(separator: "\n").lowercased()
    }

    static func withOCR(_ item: ClipItem, ocrText: String) -> String {
        let base = item.searchText
        let lower = ocrText.lowercased()
        if base.contains(lower) { return base }
        return base + "\n" + lower
    }
}

extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var collapsedWhitespace: String {
        components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    func safePrefix(_ count: Int) -> String {
        guard self.count > count else { return self }
        return String(prefix(count))
    }

    var titleCased: String {
        self.capitalized(with: Locale.current)
    }

    var isCodeLike: Bool {
        let text = self.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return false }
        let markers = ["{", "}", "[", "]", "=>", "func ", "import ", "SELECT ", "#!/", "const ", "let ", "var "]
        return markers.contains { text.contains($0) }
    }
}

extension Date {
    var relativeDescription: String {
        let interval = Date().timeIntervalSince(self)
        if interval < 10 { return "Just now" }
        if interval < 60 { return "\(Int(interval))s ago" }
        if interval < 3600 { return "\(Int(interval / 60))m ago" }
        if interval < 86400 { return "\(Int(interval / 3600))h ago" }
        if interval < 604800 { return "\(Int(interval / 86400))d ago" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: self)
    }
}

extension NSColor {
    convenience init?(hex: String) {
        var value = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("#") { value.removeFirst() }
        guard value.count == 6 || value.count == 8 else { return nil }
        guard let number = UInt64(value, radix: 16) else { return nil }
        let r, g, b, a: CGFloat
        if value.count == 8 {
            r = CGFloat((number >> 24) & 0xff) / 255
            g = CGFloat((number >> 16) & 0xff) / 255
            b = CGFloat((number >> 8) & 0xff) / 255
            a = CGFloat(number & 0xff) / 255
        } else {
            r = CGFloat((number >> 16) & 0xff) / 255
            g = CGFloat((number >> 8) & 0xff) / 255
            b = CGFloat(number & 0xff) / 255
            a = 1
        }
        self.init(srgbRed: r, green: g, blue: b, alpha: a)
    }

    var hexRGB: String {
        guard let color = usingColorSpace(.sRGB) else { return "#000000" }
        let r = Int(round(color.redComponent * 255))
        let g = Int(round(color.greenComponent * 255))
        let b = Int(round(color.blueComponent * 255))
        if color.alphaComponent < 0.999 {
            let a = Int(round(color.alphaComponent * 255))
            return String(format: "#%02X%02X%02X%02X", r, g, b, a)
        }
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}

extension NSImage {
    var pngData: Data? {
        guard let tiff = tiffRepresentation, let rep = NSBitmapImageRep(data: tiff) else { return nil }
        return rep.representation(using: .png, properties: [:])
    }

    var pixelDimensions: (width: Int, height: Int) {
        if let rep = representations.max(by: { ($0.pixelsWide * $0.pixelsHigh) < ($1.pixelsWide * $1.pixelsHigh) }) {
            return (max(rep.pixelsWide, 1), max(rep.pixelsHigh, 1))
        }
        return (max(Int(size.width), 1), max(Int(size.height), 1))
    }
}

extension NSPasteboard.PasteboardType {
    static let concealed = NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType")
    static let transient = NSPasteboard.PasteboardType("org.nspasteboard.TransientType")
    static let autoGenerated = NSPasteboard.PasteboardType("org.nspasteboard.AutoGeneratedType")
    static let source = NSPasteboard.PasteboardType("org.nspasteboard.source")
}

enum KeyCodeMap {
    static let names: [UInt32: String] = [
        0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X", 8: "C", 9: "V",
        11: "B", 12: "Q", 13: "W", 14: "E", 15: "R", 16: "Y", 17: "T",
        18: "1", 19: "2", 20: "3", 21: "4", 22: "6", 23: "5", 24: "=", 25: "9",
        26: "7", 27: "-", 28: "8", 29: "0", 30: "]", 31: "O", 32: "U", 33: "[",
        34: "I", 35: "P", 37: "L", 38: "J", 39: "'", 40: "K", 41: ";", 42: "\\",
        43: ",", 44: "/", 45: "N", 46: "M", 47: ".", 50: "`",
        65: ".", 67: "*", 69: "+", 75: "/", 76: "Enter", 78: "-", 81: "=",
        82: "0", 83: "1", 84: "2", 85: "3", 86: "4", 87: "5", 88: "6", 89: "7",
        91: "8", 92: "9",
        96: "F5", 97: "F6", 98: "F7", 99: "F3", 100: "F8", 101: "F9",
        103: "F11", 105: "F13", 107: "F14", 109: "F10", 111: "F12", 113: "F15",
        114: "Help", 115: "Home", 116: "Page Up", 117: "Forward Delete", 118: "F4",
        119: "End", 120: "F2", 121: "Page Down", 122: "F1",
        123: "←", 124: "→", 125: "↓", 126: "↑"
    ]

    static func display(keyCode: UInt32, modifiers: UInt32) -> String {
        var text = ""
        if modifiers & UInt32(controlKey) != 0 { text += "⌃" }
        if modifiers & UInt32(optionKey) != 0 { text += "⌥" }
        if modifiers & UInt32(shiftKey) != 0 { text += "⇧" }
        if modifiers & UInt32(cmdKey) != 0 { text += "⌘" }
        text += names[keyCode] ?? "Key \(keyCode)"
        return text
    }

    static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var value: UInt32 = 0
        if flags.contains(.control) { value |= UInt32(controlKey) }
        if flags.contains(.option) { value |= UInt32(optionKey) }
        if flags.contains(.shift) { value |= UInt32(shiftKey) }
        if flags.contains(.command) { value |= UInt32(cmdKey) }
        return value
    }

    static func isModifierKey(_ keyCode: UInt32) -> Bool {
        [54, 55, 56, 57, 58, 59, 60, 61, 62, 63].contains(keyCode)
    }
}

enum AppInfo {
    static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "2.0"
    }

    static var build: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
    }

    static var name: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? "Clipboard Manager"
    }
}

@MainActor
final class Debouncer {
    private var workItem: DispatchWorkItem?
    private let delay: TimeInterval
    private let action: () -> Void

    init(delay: TimeInterval, action: @escaping () -> Void) {
        self.delay = delay
        self.action = action
    }

    func call() {
        workItem?.cancel()
        let item = DispatchWorkItem { [weak self] in self?.action() }
        workItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
    }
}
