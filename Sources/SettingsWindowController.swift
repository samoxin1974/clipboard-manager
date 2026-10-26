import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController: NSWindowController {
    private let state: AppState

    init(state: AppState) {
        self.state = state
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 660, height: 760),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Clipboard Manager Settings"
        window.titlebarAppearsTransparent = false
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 620, height: 560)
        window.center()
        window.setFrameAutosaveName("ClipboardManagerSettingsWindow")
        window.contentView = NSHostingView(rootView: SettingsView().environmentObject(state).environmentObject(state.settings))
        super.init(window: window)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show() {
        if #available(macOS 14.0, *) {
            NSApp.activate()
        } else {
            NSApp.activate(ignoringOtherApps: true)
        }
        window?.makeKeyAndOrderFront(nil)
        window?.orderFrontRegardless()
        state.refreshAccessibilityStatus()
    }

    func saveSnapshot(to url: URL) {
        guard let view = window?.contentView else { return }
        view.layoutSubtreeIfNeeded()
        guard let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
        view.cacheDisplay(in: view.bounds, to: rep)
        guard let data = rep.representation(using: .png, properties: [:]) else { return }
        try? data.write(to: url, options: .atomic)
    }
}
