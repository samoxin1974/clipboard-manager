import Foundation

struct AppPaths {
    let applicationSupportDirectory: URL
    let databaseURL: URL
    let imageDirectory: URL
    let logURL: URL

    init(fileManager: FileManager = .default) throws {
        let support: URL
        if let override = ProcessInfo.processInfo.environment["CLIPBOARD_MANAGER_DATA_DIR"],
           !override.isEmpty {
            support = URL(fileURLWithPath: override, isDirectory: true)
        } else {
            let base = try fileManager.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            support = base.appendingPathComponent("Clipboard Manager Pro", isDirectory: true)
        }
        let images = support.appendingPathComponent("Images", isDirectory: true)
        try fileManager.createDirectory(at: support, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: images, withIntermediateDirectories: true)
        applicationSupportDirectory = support
        databaseURL = support.appendingPathComponent("history.sqlite")
        imageDirectory = images
        logURL = support.appendingPathComponent("debug.log")
    }
}
