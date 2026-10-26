import AppKit

@main
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private static var retained: AppDelegate?
    private var state: AppState?
    private var panelController: HistoryPanelController?
    private var settingsWindowController: SettingsWindowController?
    private var menuBarController: MenuBarController?

    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        retained = delegate
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        do {
            let paths = try AppPaths()
            AppLog.fileURL = paths.logURL
            AppLog.write("app started")
            let state = try AppState(paths: paths)
            self.state = state

            let panel = HistoryPanelController(state: state)
            let settings = SettingsWindowController(state: state)
            let menuBar = MenuBarController(state: state)
            self.panelController = panel
            self.settingsWindowController = settings
            self.menuBarController = menuBar
            state.panelController = panel
            state.settingsWindowController = settings

            menuBar.showHistory = { [weak self] in self?.panelController?.show(mode: .history) }
            menuBar.showSnippets = { [weak self] in self?.panelController?.show(mode: .snippets) }
            menuBar.showSettings = { [weak self] in self?.settingsWindowController?.show() }
            menuBar.quit = { NSApp.terminate(nil) }

            buildMainMenu()
            if let iconURL = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
               let icon = NSImage(contentsOf: iconURL) {
                NSApp.applicationIconImage = icon
            }

            state.start()

            let arguments = CommandLine.arguments
            if let snapshotIndex = arguments.firstIndex(of: "--snapshot"),
               arguments.indices.contains(snapshotIndex + 1) {
                let snapshotURL = URL(fileURLWithPath: arguments[snapshotIndex + 1])
                let wantsSettings = arguments.contains("--snapshot-settings")
                let wantsSnippets = arguments.contains("--snapshot-snippets")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                    if wantsSettings {
                        settings.show()
                    } else {
                        panel.show(mode: wantsSnippets ? .snippets : .history)
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                        if wantsSettings {
                            settings.saveSnapshot(to: snapshotURL)
                        } else {
                            panel.saveSnapshot(to: snapshotURL)
                        }
                        NSApp.terminate(nil)
                    }
                }
            } else if arguments.contains("--show-history") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                    panel.show(mode: .history)
                }
            } else if arguments.contains("--show-settings") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                    settings.show()
                }
            }
        } catch {
            let alert = NSAlert()
            alert.alertStyle = .critical
            alert.messageText = "Clipboard Manager Could Not Start"
            alert.informativeText = error.localizedDescription
            alert.addButton(withTitle: "Quit")
            alert.runModal()
            NSApp.terminate(nil)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        state?.shutdown()
        AppLog.write("app terminated")
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        panelController?.show(mode: .history)
        return true
    }

    @objc private func showHistoryAction() {
        panelController?.show(mode: .history)
    }

    @objc private func showSnippetsAction() {
        panelController?.show(mode: .snippets)
    }

    @objc private func showSettingsAction() {
        settingsWindowController?.show()
    }

    @objc private func captureCurrentAction() {
        state?.captureCurrentClipboard()
    }

    @objc private func aboutAction() {
        let credits = NSMutableAttributedString(
            string: "A local-first clipboard manager with instant paste, OCR image search, snippets, and transforms.\n\nUniversal build for Intel and Apple Silicon. No account, no cloud, no App Store.",
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

    private func buildMainMenu() {
        let mainMenu = NSMenu()

        let appItem = NSMenuItem()
        mainMenu.addItem(appItem)
        let appMenu = NSMenu()
        appItem.submenu = appMenu

        let about = NSMenuItem(title: "About Clipboard Manager", action: #selector(aboutAction), keyEquivalent: "")
        about.target = self
        appMenu.addItem(about)
        appMenu.addItem(.separator())

        let settings = NSMenuItem(title: "Settings…", action: #selector(showSettingsAction), keyEquivalent: ",")
        settings.target = self
        appMenu.addItem(settings)
        appMenu.addItem(.separator())

        let services = NSMenuItem(title: "Services", action: nil, keyEquivalent: "")
        let servicesMenu = NSMenu()
        services.submenu = servicesMenu
        appMenu.addItem(services)
        NSApp.servicesMenu = servicesMenu
        appMenu.addItem(.separator())

        appMenu.addItem(NSMenuItem(title: "Hide Clipboard Manager", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h"))
        let hideOthers = NSMenuItem(title: "Hide Others", action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h")
        hideOthers.keyEquivalentModifierMask = [.command, .option]
        appMenu.addItem(hideOthers)
        appMenu.addItem(NSMenuItem(title: "Show All", action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: ""))
        appMenu.addItem(.separator())
        appMenu.addItem(NSMenuItem(title: "Quit Clipboard Manager", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        let editItem = NSMenuItem()
        mainMenu.addItem(editItem)
        let editMenu = NSMenu(title: "Edit")
        editItem.submenu = editMenu
        editMenu.addItem(NSMenuItem(title: "Undo", action: Selector(("undo:")), keyEquivalent: "z"))
        editMenu.addItem(NSMenuItem(title: "Redo", action: Selector(("redo:")), keyEquivalent: "Z"))
        editMenu.addItem(.separator())
        editMenu.addItem(NSMenuItem(title: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x"))
        editMenu.addItem(NSMenuItem(title: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c"))
        editMenu.addItem(NSMenuItem(title: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v"))
        editMenu.addItem(NSMenuItem(title: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a"))

        let viewItem = NSMenuItem()
        mainMenu.addItem(viewItem)
        let viewMenu = NSMenu(title: "View")
        viewItem.submenu = viewMenu
        let history = NSMenuItem(title: "Show Clipboard History", action: #selector(showHistoryAction), keyEquivalent: "`")
        history.keyEquivalentModifierMask = [.control]
        history.target = self
        viewMenu.addItem(history)
        let snippets = NSMenuItem(title: "Show Snippets", action: #selector(showSnippetsAction), keyEquivalent: "s")
        snippets.keyEquivalentModifierMask = [.command, .shift]
        snippets.target = self
        viewMenu.addItem(snippets)
        viewMenu.addItem(.separator())
        let capture = NSMenuItem(title: "Capture Current Clipboard", action: #selector(captureCurrentAction), keyEquivalent: "")
        capture.target = self
        viewMenu.addItem(capture)

        let windowItem = NSMenuItem()
        mainMenu.addItem(windowItem)
        let windowMenu = NSMenu(title: "Window")
        windowItem.submenu = windowMenu
        windowMenu.addItem(NSMenuItem(title: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m"))
        windowMenu.addItem(NSMenuItem(title: "Zoom", action: #selector(NSWindow.performZoom(_:)), keyEquivalent: ""))
        windowMenu.addItem(.separator())
        windowMenu.addItem(NSMenuItem(title: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w"))
        NSApp.windowsMenu = windowMenu

        NSApp.mainMenu = mainMenu
    }
}
