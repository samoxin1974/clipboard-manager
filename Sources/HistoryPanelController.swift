import AppKit
import SwiftUI

final class HistoryPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

@MainActor
final class HistoryPanelController: NSObject, NSWindowDelegate {
    private let state: AppState
    private var panel: HistoryPanel?
    private var keyMonitor: Any?

    init(state: AppState) {
        self.state = state
        super.init()
        installKeyMonitor()
    }

    deinit {
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
        }
    }

    func show(mode: PanelMode = .history) {
        let panel = makePanelIfNeeded()
        state.panelWillShow(mode: mode)
        state.mode = mode
        center(panel)
        if #available(macOS 14.0, *) {
            NSApp.activate()
        } else {
            NSApp.activate(ignoringOtherApps: true)
        }
        panel.makeKeyAndOrderFront(nil)
        panel.orderFrontRegardless()
        DispatchQueue.main.async {
            self.state.focusSearchRequest += 1
        }
    }

    func hide(restoreFocus: Bool = true) {
        panel?.orderOut(nil)
        if restoreFocus {
            state.restorePreviousApp()
        }
    }

    func toggle() {
        guard let panel, panel.isVisible else {
            show(mode: .history)
            return
        }
        hide()
    }

    private func makePanelIfNeeded() -> HistoryPanel {
        if let panel { return panel }
        let panel = HistoryPanel(
            contentRect: NSRect(x: 0, y: 0, width: 980, height: 660),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        panel.title = "Clipboard History"
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.minSize = NSSize(width: 800, height: 520)
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true
        panel.delegate = self
        panel.contentView = NSHostingView(rootView: HistoryView().environmentObject(state))
        self.panel = panel
        return panel
    }

    private func center(_ panel: NSPanel) {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first(where: { $0.frame.contains(mouse) }) ?? NSScreen.main
        guard let visible = screen?.visibleFrame else { return }
        let size = panel.frame.size
        let origin = NSPoint(
            x: visible.midX - size.width / 2,
            y: visible.midY - size.height / 2 + 20
        )
        panel.setFrameOrigin(origin)
    }

    private func installKeyMonitor() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            return self.handle(event)
        }
    }

    private func handle(_ event: NSEvent) -> NSEvent? {
        guard let panel, panel.isVisible, panel.isKeyWindow, panel.attachedSheet == nil else {
            return event
        }
        let command = event.modifierFlags.contains(.command)
        let keyCode = event.keyCode

        if keyCode == 53 {
            if !state.searchText.isEmpty {
                state.searchText = ""
                state.ensureSelectionVisible()
                state.ensureSnippetSelectionVisible()
            } else {
                hide()
            }
            return nil
        }

        if keyCode == 36 || keyCode == 76 {
            if state.mode == .snippets {
                if command {
                    state.pasteSnippetRequest += 1
                    return nil
                }
                if isEditingLongText() { return event }
                state.pasteSnippetRequest += 1
            } else {
                state.pasteSelected()
            }
            return nil
        }

        if keyCode == 125 {
            if state.mode == .snippets {
                if isEditingLongText() { return event }
                state.moveSnippetSelection(by: 1)
            } else {
                state.moveSelection(by: 1)
            }
            return nil
        }

        if keyCode == 126 {
            if state.mode == .snippets {
                if isEditingLongText() { return event }
                state.moveSnippetSelection(by: -1)
            } else {
                state.moveSelection(by: -1)
            }
            return nil
        }

        if command, let characters = event.charactersIgnoringModifiers?.lowercased() {
            if characters.count == 1, let digit = Int(characters), digit >= 1, digit <= 9 {
                if state.mode == .snippets {
                    state.quickPasteSnippet(index: digit - 1)
                } else {
                    state.quickPaste(index: digit - 1)
                }
                return nil
            }
            switch characters {
            case "c":
                if textEditorHasSelection() { return event }
                if state.mode == .snippets {
                    state.copySnippetRequest += 1
                } else {
                    state.copySelected()
                }
                return nil
            case "f":
                state.focusSearchRequest += 1
                return nil
            case "p":
                if state.mode == .history {
                    state.togglePinSelected()
                    return nil
                }
            case "s":
                if !event.modifierFlags.contains(.shift), state.mode == .snippets {
                    state.saveSnippetRequest += 1
                    return nil
                }
            default:
                break
            }
        }

        if keyCode == 51 || keyCode == 117 {
            if state.mode == .snippets {
                if isEditingLongText() || state.snippetTitleFocused { return event }
            }
            if state.searchFieldFocused, !state.searchText.isEmpty { return event }
            if state.mode == .snippets {
                if let snippet = state.selectedSnippet {
                    state.deleteSnippet(snippet)
                }
            } else {
                state.deleteSelected()
            }
            return nil
        }

        return event
    }

    private func isEditingText() -> Bool {
        panel?.firstResponder is NSTextView
    }

    private func isEditingLongText() -> Bool {
        guard let textView = panel?.firstResponder as? NSTextView else { return false }
        return !textView.isFieldEditor
    }

    private func textEditorHasSelection() -> Bool {
        guard let textView = panel?.firstResponder as? NSTextView else { return false }
        return textView.selectedRange().length > 0
    }

    func saveSnapshot(to url: URL) {
        guard let panel, let view = panel.contentView else { return }
        view.layoutSubtreeIfNeeded()
        guard let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
        view.cacheDisplay(in: view.bounds, to: rep)
        guard let data = rep.representation(using: .png, properties: [:]) else { return }
        do {
            try data.write(to: url, options: .atomic)
            AppLog.write("snapshot saved: \(url.path)")
        } catch {
            AppLog.write("snapshot failed: \(error.localizedDescription)")
        }
    }

    func windowWillClose(_ notification: Notification) {
        if let panel, panel.isVisible {
            panel.orderOut(nil)
        }
    }
}
