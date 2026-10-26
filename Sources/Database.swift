import Foundation
import SQLite3

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

struct SaveResult {
    let item: ClipItem
    let inserted: Bool
}

final class ClipboardDatabase {
    private var db: OpaquePointer?
    private let queue = DispatchQueue(label: "local.clipboardmanager.pro.database")
    private let columnList = "id, created_at, kind, plain_text, html_text, image_file_name, image_width, image_height, file_paths, color_hex, source_bundle_id, source_name, content_hash, pinned, ocr_text, byte_size, search_text"

    init(url: URL) throws {
        var handle: OpaquePointer?
        let result = sqlite3_open(url.path, &handle)
        guard result == SQLITE_OK, let handle else {
            let message = handle.map { String(cString: sqlite3_errmsg($0)) } ?? "Unknown SQLite error"
            if let handle { sqlite3_close(handle) }
            throw DatabaseError.open(message)
        }
        db = handle
        sqlite3_busy_timeout(handle, 2_000)
        try execute("PRAGMA journal_mode=WAL;")
        try execute("PRAGMA synchronous=NORMAL;")
        try createSchema()
    }

    deinit {
        if let db {
            sqlite3_close(db)
        }
    }

    private func createSchema() throws {
        try execute("""
        CREATE TABLE IF NOT EXISTS items (
            id TEXT PRIMARY KEY,
            created_at REAL NOT NULL,
            kind TEXT NOT NULL,
            plain_text TEXT,
            html_text TEXT,
            image_file_name TEXT,
            image_width INTEGER,
            image_height INTEGER,
            file_paths TEXT NOT NULL DEFAULT '[]',
            color_hex TEXT,
            source_bundle_id TEXT,
            source_name TEXT,
            content_hash TEXT NOT NULL UNIQUE,
            pinned INTEGER NOT NULL DEFAULT 0,
            ocr_text TEXT,
            byte_size INTEGER NOT NULL DEFAULT 0,
            search_text TEXT NOT NULL
        );
        """)
        try execute("CREATE INDEX IF NOT EXISTS items_created_at_idx ON items(created_at DESC);")
        try execute("CREATE INDEX IF NOT EXISTS items_pinned_idx ON items(pinned DESC, created_at DESC);")
        try execute("CREATE INDEX IF NOT EXISTS items_kind_idx ON items(kind);")
        try execute("CREATE INDEX IF NOT EXISTS items_source_idx ON items(source_bundle_id);")
        try execute("CREATE INDEX IF NOT EXISTS items_hash_idx ON items(content_hash);")
        try execute("""
        CREATE TABLE IF NOT EXISTS snippets (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            body TEXT NOT NULL,
            created_at REAL NOT NULL,
            updated_at REAL NOT NULL
        );
        """)
    }

    func execute(_ sql: String, _ parameters: [Any?] = []) throws {
        guard let db else { throw DatabaseError.closed }
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
            throw DatabaseError.prepare(String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(statement) }
        try bind(parameters, to: statement)
        let step = sqlite3_step(statement)
        guard step == SQLITE_DONE || step == SQLITE_ROW else {
            throw DatabaseError.step(String(cString: sqlite3_errmsg(db)))
        }
    }

    func query(_ sql: String, _ parameters: [Any?] = [], row: (OpaquePointer) throws -> Void) throws {
        guard let db else { throw DatabaseError.closed }
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
            throw DatabaseError.prepare(String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(statement) }
        try bind(parameters, to: statement)
        while true {
            let step = sqlite3_step(statement)
            if step == SQLITE_ROW {
                try row(statement)
            } else if step == SQLITE_DONE {
                break
            } else {
                throw DatabaseError.step(String(cString: sqlite3_errmsg(db)))
            }
        }
    }

    private func bind(_ parameters: [Any?], to statement: OpaquePointer) throws {
        for (offset, value) in parameters.enumerated() {
            let index = Int32(offset + 1)
            let result: Int32
            switch value {
            case nil, is NSNull:
                result = sqlite3_bind_null(statement, index)
            case let value as String:
                result = sqlite3_bind_text(statement, index, (value as NSString).utf8String, -1, SQLITE_TRANSIENT)
            case let value as Bool:
                result = sqlite3_bind_int64(statement, index, value ? 1 : 0)
            case let value as Int:
                result = sqlite3_bind_int64(statement, index, Int64(value))
            case let value as Int64:
                result = sqlite3_bind_int64(statement, index, value)
            case let value as Double:
                result = sqlite3_bind_double(statement, index, value)
            case let value as Data:
                result = value.withUnsafeBytes { buffer in
                    sqlite3_bind_blob(statement, index, buffer.baseAddress, Int32(value.count), SQLITE_TRANSIENT)
                }
            default:
                result = sqlite3_bind_text(statement, index, "\(value!)", -1, SQLITE_TRANSIENT)
            }
            if result != SQLITE_OK {
                throw DatabaseError.bind("Could not bind parameter \(offset + 1).")
            }
        }
    }

    private func text(_ statement: OpaquePointer, _ index: Int32) -> String? {
        guard let pointer = sqlite3_column_text(statement, index) else { return nil }
        return String(cString: pointer)
    }

    private func integer(_ statement: OpaquePointer, _ index: Int32) -> Int? {
        guard sqlite3_column_type(statement, index) != SQLITE_NULL else { return nil }
        return Int(sqlite3_column_int64(statement, index))
    }

    private func item(from statement: OpaquePointer) -> ClipItem {
        let id = text(statement, 0) ?? UUID().uuidString
        let createdAt = Date(timeIntervalSince1970: sqlite3_column_double(statement, 1))
        let kind = ClipKind(rawValue: text(statement, 2) ?? "") ?? .text
        let filePathsText = text(statement, 8) ?? "[]"
        let filePaths = (try? JSONDecoder().decode([String].self, from: Data(filePathsText.utf8))) ?? []
        return ClipItem(
            id: id,
            createdAt: createdAt,
            kind: kind,
            plainText: text(statement, 3),
            htmlText: text(statement, 4),
            imageFileName: text(statement, 5),
            imageWidth: integer(statement, 6),
            imageHeight: integer(statement, 7),
            filePaths: filePaths,
            colorHex: text(statement, 9),
            sourceBundleID: text(statement, 10),
            sourceName: text(statement, 11),
            contentHash: text(statement, 12) ?? "",
            pinned: sqlite3_column_int64(statement, 13) != 0,
            ocrText: text(statement, 14),
            byteSize: integer(statement, 15) ?? 0,
            searchText: text(statement, 16) ?? ""
        )
    }

    private func encodedFilePaths(_ paths: [String]) -> String {
        guard let data = try? JSONEncoder().encode(paths) else { return "[]" }
        return String(data: data, encoding: .utf8) ?? "[]"
    }

    @discardableResult
    func save(_ incoming: ClipItem) throws -> SaveResult {
        var existing: ClipItem?
        try query("SELECT \(columnList) FROM items WHERE content_hash = ? LIMIT 1", [incoming.contentHash]) { statement in
            existing = item(from: statement)
        }
        if var current = existing {
            current.createdAt = incoming.createdAt
            current.kind = incoming.kind
            current.plainText = incoming.plainText ?? current.plainText
            current.htmlText = incoming.htmlText ?? current.htmlText
            current.imageFileName = incoming.imageFileName ?? current.imageFileName
            current.imageWidth = incoming.imageWidth ?? current.imageWidth
            current.imageHeight = incoming.imageHeight ?? current.imageHeight
            current.filePaths = incoming.filePaths.isEmpty ? current.filePaths : incoming.filePaths
            current.colorHex = incoming.colorHex ?? current.colorHex
            current.sourceBundleID = incoming.sourceBundleID ?? current.sourceBundleID
            current.sourceName = incoming.sourceName ?? current.sourceName
            current.byteSize = incoming.byteSize
            current.searchText = incoming.searchText
            if let incomingOCR = incoming.ocrText, !incomingOCR.isEmpty {
                current.ocrText = incomingOCR
            }
            try execute("""
            UPDATE items SET
                created_at = ?, kind = ?, plain_text = ?, html_text = ?, image_file_name = ?,
                image_width = ?, image_height = ?, file_paths = ?, color_hex = ?,
                source_bundle_id = ?, source_name = ?, byte_size = ?, search_text = ?, ocr_text = ?
            WHERE id = ?
            """, [
                current.createdAt.timeIntervalSince1970, current.kind.rawValue, current.plainText,
                current.htmlText, current.imageFileName, current.imageWidth, current.imageHeight,
                encodedFilePaths(current.filePaths), current.colorHex, current.sourceBundleID,
                current.sourceName, current.byteSize, current.searchText, current.ocrText, current.id
            ])
            return SaveResult(item: current, inserted: false)
        }

        try execute("""
        INSERT INTO items (
            id, created_at, kind, plain_text, html_text, image_file_name, image_width,
            image_height, file_paths, color_hex, source_bundle_id, source_name,
            content_hash, pinned, ocr_text, byte_size, search_text
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """, [
            incoming.id, incoming.createdAt.timeIntervalSince1970, incoming.kind.rawValue,
            incoming.plainText, incoming.htmlText, incoming.imageFileName, incoming.imageWidth,
            incoming.imageHeight, encodedFilePaths(incoming.filePaths), incoming.colorHex,
            incoming.sourceBundleID, incoming.sourceName, incoming.contentHash,
            incoming.pinned, incoming.ocrText, incoming.byteSize, incoming.searchText
        ])
        return SaveResult(item: incoming, inserted: true)
    }

    func recent(limit: Int = 1_000) throws -> [ClipItem] {
        var results: [ClipItem] = []
        try query("SELECT \(columnList) FROM items ORDER BY pinned DESC, created_at DESC LIMIT ?", [limit]) { statement in
            results.append(item(from: statement))
        }
        return results
    }

    func allItems() throws -> [ClipItem] {
        try recent(limit: 100_000)
    }

    func item(id: String) throws -> ClipItem? {
        var result: ClipItem?
        try query("SELECT \(columnList) FROM items WHERE id = ? LIMIT 1", [id]) { statement in
            result = item(from: statement)
        }
        return result
    }

    @discardableResult
    func setPinned(_ pinned: Bool, id: String) throws -> Bool {
        try execute("UPDATE items SET pinned = ? WHERE id = ?", [pinned, id])
        return true
    }

    @discardableResult
    func delete(id: String) throws -> [String] {
        var fileNames: [String] = []
        try query("SELECT image_file_name FROM items WHERE id = ? AND image_file_name IS NOT NULL", [id]) { statement in
            if let name = text(statement, 0) { fileNames.append(name) }
        }
        try execute("DELETE FROM items WHERE id = ?", [id])
        return fileNames
    }

    @discardableResult
    func delete(ids: [String]) throws -> [String] {
        var fileNames: [String] = []
        for id in ids {
            fileNames.append(contentsOf: try delete(id: id))
        }
        return fileNames
    }

    @discardableResult
    func clear(keepPinned: Bool = false) throws -> [String] {
        var fileNames: [String] = []
        let selection = keepPinned
            ? "SELECT image_file_name FROM items WHERE pinned = 0 AND image_file_name IS NOT NULL"
            : "SELECT image_file_name FROM items WHERE image_file_name IS NOT NULL"
        try query(selection) { statement in
            if let name = text(statement, 0) { fileNames.append(name) }
        }
        if keepPinned {
            try execute("DELETE FROM items WHERE pinned = 0")
        } else {
            try execute("DELETE FROM items")
        }
        return fileNames
    }

    @discardableResult
    func trim(maxItems: Int, retentionDays: Int) throws -> [String] {
        let limit = max(maxItems, 1)
        let hasAgeLimit = retentionDays > 0
        let cutoff = hasAgeLimit ? Date().addingTimeInterval(-Double(retentionDays) * 86_400).timeIntervalSince1970 : 0
        let predicate = """
        pinned = 0 AND (
            (? = 1 AND created_at < ?)
            OR id NOT IN (
                SELECT id FROM items WHERE pinned = 0 ORDER BY created_at DESC LIMIT ?
            )
        )
        """
        var fileNames: [String] = []
        try query("SELECT image_file_name FROM items WHERE \(predicate) AND image_file_name IS NOT NULL", [hasAgeLimit ? 1 : 0, cutoff, limit]) { statement in
            if let name = text(statement, 0) { fileNames.append(name) }
        }
        try execute("DELETE FROM items WHERE \(predicate)", [hasAgeLimit ? 1 : 0, cutoff, limit])
        return fileNames
    }

    func updateOCR(id: String, text: String, searchText: String) throws {
        try execute("UPDATE items SET ocr_text = ?, search_text = ? WHERE id = ?", [text, searchText, id])
    }

    func count() throws -> Int {
        var value = 0
        try query("SELECT COUNT(*) FROM items") { statement in
            value = Int(sqlite3_column_int64(statement, 0))
        }
        return value
    }

    func databaseSize() -> Int64 {
        guard let db, let path = sqlite3_db_filename(db, "main") else { return 0 }
        let attributes = try? FileManager.default.attributesOfItem(atPath: String(cString: path))
        return (attributes?[.size] as? NSNumber)?.int64Value ?? 0
    }

    func allSnippets() throws -> [Snippet] {
        var results: [Snippet] = []
        try query("SELECT id, title, body, created_at, updated_at FROM snippets ORDER BY updated_at DESC") { statement in
            results.append(Snippet(
                id: text(statement, 0) ?? UUID().uuidString,
                title: text(statement, 1) ?? "Untitled",
                body: text(statement, 2) ?? "",
                createdAt: Date(timeIntervalSince1970: sqlite3_column_double(statement, 3)),
                updatedAt: Date(timeIntervalSince1970: sqlite3_column_double(statement, 4))
            ))
        }
        return results
    }

    func saveSnippet(_ snippet: Snippet) throws {
        try execute("""
        INSERT INTO snippets (id, title, body, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?)
        ON CONFLICT(id) DO UPDATE SET title = excluded.title, body = excluded.body, updated_at = excluded.updated_at
        """, [
            snippet.id, snippet.title, snippet.body,
            snippet.createdAt.timeIntervalSince1970, snippet.updatedAt.timeIntervalSince1970
        ])
    }

    func deleteSnippet(id: String) throws {
        try execute("DELETE FROM snippets WHERE id = ?", [id])
    }
}

enum DatabaseError: LocalizedError {
    case closed
    case open(String)
    case prepare(String)
    case step(String)
    case bind(String)

    var errorDescription: String? {
        switch self {
        case .closed: return "The clipboard database is closed."
        case let .open(message): return "Could not open the clipboard database: \(message)"
        case let .prepare(message): return "Could not prepare a database query: \(message)"
        case let .step(message): return "A database query failed: \(message)"
        case let .bind(message): return "A database parameter failed: \(message)"
        }
    }
}
