import AppKit

@MainActor
final class MenuBarController: NSObject {
    private let state: AppState
    private let statusItem: NSStatusItem

    var showHistory: (() -> Void)?
    var showSnippets: (() -> Void)?
    var showSettings: (() -> Void)?
    var quit: (() -> Void)?

    init(state: AppState) {
        self.state = state
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()
        configureStatusItem()
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else { return }
        let configuration = NSImage.SymbolConfiguration(pointSize: 15, weight: .semibold)
        let image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "Clipboard Manager")?
            .withSymbolConfiguration(configuration)
        image?.isTemplate = true
        button.image = image
        button.toolTip = "Clipboard Manager — \(state.settings.shortcut.display)"
        button.target = self
        button.action = #selector(statusClicked(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    @objc private func statusClicked(_ sender: Any?) {
        guard let event = NSApp.currentEvent else {
            showHistory?()
            return
        }
        if event.type == .rightMouseUp {
            showMenu()
        } else if let showHistory {
            if NSApp.keyWindow is HistoryPanel {
                NSApp.keyWindow?.orderOut(nil)
                state.restorePreviousApp()
            } else {
                showHistory()
            }
        }
    }

    private func showMenu() {
        statusItem.menu = buildMenu()
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false

        menu.addItem(item(
            title: "Show Clipboard History",
            action: #selector(showHistoryAction),
            keyEquivalent: "`",
            modifiers: [.control]
        ))
        menu.addItem(item(
            title: "Show Snippets",
            action: #selector(showSnippetsAction),
            keyEquivalent: "s",
            modifiers: [.command, .shift]
        ))
        menu.addItem(.separator())
        menu.addItem(item(
            title: "Capture Current Clipboard",
            action: #selector(captureAction),
            keyEquivalent: ""
        ))

        let pause = item(
            title: state.settings.monitorEnabled ? "Pause Clipboard Monitoring" : "Resume Clipboard Monitoring",
            action: #selector(toggleMonitoringAction),
            keyEquivalent: ""
        )
        pause.state = state.settings.monitorEnabled ? .off : .on
        menu.addItem(pause)
        menu.addItem(.separator())

        if !AccessibilityPermission.isTrusted {
            menu.addItem(item(
                title: "Grant Accessibility Permission…",
                action: #selector(accessibilityAction),
                keyEquivalent: ""
            ))
        } else {
            let granted = item(
                title: "Accessibility Permission Granted",
                action: nil,
                keyEquivalent: ""
            )
            granted.isEnabled = false
            menu.addItem(granted)
        }

        menu.addItem(item(
            title: "Settings…",
            action: #selector(settingsAction),
            keyEquivalent: ","
        ))
        menu.addItem(item(
            title: "About Clipboard Manager",
            action: #selector(aboutAction),
            keyEquivalent: ""
        ))
        menu.addItem(.separator())
        menu.addItem(item(
            title: "Quit Clipboard Manager",
            action: #selector(quitAction),
            keyEquivalent: "q"
        ))
        return menu
    }

    private func item(
        title: String,
        action: Selector?,
        keyEquivalent: String,
        modifiers: NSEvent.ModifierFlags = [.command]
    ) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: keyEquivalent)
        item.target = self
        item.keyEquivalentModifierMask = keyEquivalent.isEmpty ? [] : modifiers
        return item
    }

    @objc private func showHistoryAction() {
        showHistory?()
    }

    @objc private func showSnippetsAction() {
        showSnippets?()
    }

    @objc private func captureAction() {
        state.captureCurrentClipboard()
    }

    @objc private func toggleMonitoringAction() {
        state.toggleMonitoring()
        configureStatusItem()
    }

    @objc private func accessibilityAction() {
        state.requestAccessibilityPermission()
    }

    @objc private func settingsAction() {
        showSettings?()
    }

    @objc private func aboutAction() {
        let credits = NSAttributedString(
            string: "Local-first clipboard history, instant paste, OCR image search, snippets, and transforms.\nUniversal Intel + Apple Silicon build.",
            attributes: [
                .font: NSFont.systemFont(ofSize: 11),
                .foregroundColor: NSColor.secondaryLabelColor
            ]
        )
        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationName: "Clipboard Manager",
            .applicationVersion: AppInfo.version,
            .version: AppInfo.build,
            .credits: credits
        ])
    }

    @objc private func quitAction() {
        quit?()
    }
}
