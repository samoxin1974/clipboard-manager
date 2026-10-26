import Foundation
import AppKit
import ApplicationServices

final class PasteController {
    private let pasteboard: NSPasteboard
    private let imageStore: ImageStore

    init(pasteboard: NSPasteboard = .general, imageStore: ImageStore) {
        self.pasteboard = pasteboard
        self.imageStore = imageStore
    }

    @discardableResult
    func write(item: ClipItem, variant: PasteVariant = .normal, plainTextOverride: Bool = false) -> Bool {
        let usePlainText = plainTextOverride || variant == .plainText || variant.isTransform
        switch item.kind {
        case .text, .richText, .link:
            guard let text = item.plainText else { return false }
            let output = variant.apply(to: text) ?? text
            pasteboard.clearContents()
            if item.kind == .richText, !usePlainText, let html = item.htmlText, !html.isEmpty {
                _ = pasteboard.setString(output, forType: .string)
                _ = pasteboard.setString(html, forType: .html)
                if let attributed = HTMLTools.attributedString(fromHTML: html) {
                    let range = NSRange(location: 0, length: attributed.length)
                    if let rtf = try? attributed.data(from: range, documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]) {
                        _ = pasteboard.setData(rtf, forType: .rtf)
                    }
                }
            } else {
                _ = pasteboard.setString(output, forType: .string)
                if item.kind == .link, let url = URL(string: output) {
                    _ = pasteboard.setString(url.absoluteString, forType: .URL)
                }
            }
            return true
        case .image:
            guard let fileName = item.imageFileName,
                  let image = imageStore.image(named: fileName),
                  let png = image.pngData else { return false }
            pasteboard.clearContents()
            _ = pasteboard.setData(png, forType: .png)
            if let tiff = image.tiffRepresentation {
                _ = pasteboard.setData(tiff, forType: .tiff)
            }
            return true
        case .file:
            let urls = item.filePaths.map { URL(fileURLWithPath: $0) as NSURL }
            guard !urls.isEmpty else { return false }
            pasteboard.clearContents()
            return pasteboard.writeObjects(urls)
        case .color:
            guard let hex = item.colorHex, let color = NSColor(hex: hex) else { return false }
            pasteboard.clearContents()
            return pasteboard.writeObjects([color])
        }
    }

    @discardableResult
    func write(text: String) -> Bool {
        pasteboard.clearContents()
        return pasteboard.setString(text, forType: .string)
    }

    func activate(_ app: NSRunningApplication?) {
        guard let app, !app.isTerminated else { return }
        guard app.bundleIdentifier != Bundle.main.bundleIdentifier else { return }
        app.activate(options: [.activateAllWindows])
    }

    @discardableResult
    func sendPasteCommand() -> Bool {
        guard AccessibilityPermission.isTrusted else { return false }
        guard let source = CGEventSource(stateID: .hidSystemState) else { return false }
        let keyCode: CGKeyCode = 0x09
        guard let down = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false) else {
            return false
        }
        down.flags = .maskCommand
        up.flags = .maskCommand
        down.post(tap: .cghidEventTap)
        usleep(18_000)
        up.post(tap: .cghidEventTap)
        return true
    }

    func autoPaste(to app: NSRunningApplication?, completion: ((Bool) -> Void)? = nil) {
        guard AccessibilityPermission.isTrusted else {
            completion?(false)
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak self] in
            guard let self else { return }
            self.activate(app)
            self.waitForActivation(app, attempts: 14) { ready in
                guard ready else {
                    completion?(false)
                    return
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.07) {
                    completion?(self.sendPasteCommand())
                }
            }
        }
    }

    private func waitForActivation(
        _ app: NSRunningApplication?,
        attempts: Int,
        completion: @escaping (Bool) -> Void
    ) {
        guard let app, !app.isTerminated else {
            completion(true)
            return
        }
        if NSWorkspace.shared.frontmostApplication?.processIdentifier == app.processIdentifier {
            completion(true)
            return
        }
        guard attempts > 0 else {
            completion(false)
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.04) { [weak self] in
            self?.waitForActivation(app, attempts: attempts - 1, completion: completion)
        }
    }
}
