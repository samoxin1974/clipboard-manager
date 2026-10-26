import SwiftUI
import AppKit

struct SettingsView: View {
    @EnvironmentObject private var state: AppState
    @EnvironmentObject private var settings: SettingsStore
    @State private var showClearConfirm = false

    var body: some View {
        ZStack {
            PanelBackground()

            VStack(spacing: 0) {
                header
                Divider().opacity(0.5)

                ScrollView {
                    VStack(spacing: 14) {
                        generalCard
                        historyCard
                        dataCard
                        aboutCard
                    }
                    .padding(16)
                }
            }
        }
        .frame(minWidth: 620, minHeight: 560)
        .onAppear {
            state.refreshAccessibilityStatus()
            settings.refreshLaunchAtLogin()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            state.refreshAccessibilityStatus()
            settings.refreshLaunchAtLogin()
        }
        .alert("Clear Clipboard History?", isPresented: $showClearConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Clear Unpinned", role: .destructive) {
                state.clearHistory(keepPinned: true)
            }
            Button("Clear Everything", role: .destructive) {
                state.clearHistory(keepPinned: false)
            }
        } message: {
            Text("This cannot be undone. Pinned items can be kept while the rest is removed.")
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            BrandMark(size: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text("Clipboard Manager Settings")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                Text("Version \(AppInfo.version) (\(AppInfo.build)) · local-only clipboard history")
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                state.revealDataFolder()
            } label: {
                Label("Reveal Data", systemImage: "folder")
            }
            .buttonStyle(SecondaryActionButtonStyle())
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial.opacity(0.48))
    }

    private var generalCard: some View {
        SettingsCard(
            icon: "slider.horizontal.3",
            title: "General",
            subtitle: "How Clipboard Manager opens and pastes."
        ) {
            SettingsRow(
                icon: "command",
                title: "Global shortcut",
                detail: "Press this anywhere to open clipboard history."
            ) {
                HStack(spacing: 8) {
                    ShortcutRecorder(
                        displayText: settings.shortcut.display,
                        onCaptured: { shortcut in
                            settings.shortcut = shortcut
                            state.showToast("Shortcut updated")
                        },
                        onInvalidCapture: {
                            state.showToast("Use at least one modifier key")
                        }
                    )
                    .frame(width: 168, height: 31)

                    Button("Reset") {
                        settings.shortcut = .defaultValue
                        state.showToast("Shortcut reset")
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                }
            }

            SettingsDivider()

            SettingsRow(
                icon: "arrow.turn.down.left",
                title: "Paste automatically",
                detail: "After choosing an item, send ⌘V to the previous app. Requires Accessibility permission."
            ) {
                Toggle("", isOn: $settings.pasteAutomatically)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.small)
            }

            SettingsDivider()

            SettingsRow(
                icon: "textformat",
                title: "Keep rich text formatting",
                detail: "Paste HTML and RTF with their original styling when available."
            ) {
                Toggle("", isOn: $settings.pasteRichText)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.small)
            }

            SettingsDivider()

            SettingsRow(
                icon: "power",
                title: "Launch at login",
                detail: state.launchAtLoginStatus
            ) {
                Toggle("", isOn: Binding(
                    get: { settings.launchAtLogin },
                    set: { state.updateLaunchAtLogin($0) }
                ))
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
            }

            SettingsDivider()

            SettingsRow(
                icon: "hand.raised",
                title: "Accessibility permission",
                detail: state.accessibilityTrusted
                    ? "Granted — instant paste is ready."
                    : "Needed to send ⌘V automatically. Manual copy still works."
            ) {
                if state.accessibilityTrusted {
                    Label("Granted", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                } else {
                    Button {
                        state.requestAccessibilityPermission()
                    } label: {
                        Label("Grant Access…", systemImage: "arrow.up.forward")
                    }
                    .buttonStyle(SecondaryActionButtonStyle())
                    .controlSize(.small)
                }
            }
        }
    }

    private var historyCard: some View {
        SettingsCard(
            icon: "clock.arrow.circlepath",
            title: "History",
            subtitle: "Choose what is captured and how long it stays."
        ) {
            SettingsRow(
                icon: "tray.full",
                title: "Maximum items",
                detail: "Pinned items are always kept. Older unpinned items are trimmed first."
            ) {
                HStack(spacing: 7) {
                    Text("\(settings.maxItems)")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .frame(minWidth: 38, alignment: .trailing)
                    Stepper(
                        "",
                        value: $settings.maxItems,
                        in: 50...5_000,
                        step: 50
                    )
                    .labelsHidden()
                }
            }

            SettingsDivider()

            SettingsRow(
                icon: "calendar.badge.clock",
                title: "Retention",
                detail: settings.retentionDays == 0
                    ? "Items are kept forever unless trimmed by the item limit."
                    : "Delete unpinned items older than \(settings.retentionDays) days."
            ) {
                HStack(spacing: 7) {
                    Text(settings.retentionDays == 0 ? "Forever" : "\(settings.retentionDays)d")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .frame(minWidth: 45, alignment: .trailing)
                    Stepper(
                        "",
                        value: $settings.retentionDays,
                        in: 0...3_650,
                        step: 30
                    )
                    .labelsHidden()
                }
            }

            SettingsDivider()

            SettingsRow(
                icon: "text.viewfinder",
                title: "OCR image text",
                detail: "Recognize text in copied images so you can search it later."
            ) {
                Toggle("", isOn: $settings.ocrEnabled)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.small)
            }

            SettingsDivider()

            SettingsRow(
                icon: "eye.slash",
                title: "Skip concealed content",
                detail: "Ignore passwords and clipboard items marked concealed or transient."
            ) {
                Toggle("", isOn: $settings.skipConcealed)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.small)
            }

            SettingsDivider()

            SettingsRow(
                icon: "wand.and.stars",
                title: "Skip generated content",
                detail: "Ignore clipboard entries marked as auto-generated by other apps."
            ) {
                Toggle("", isOn: $settings.skipAutoGenerated)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.small)
            }

            SettingsDivider()

            SettingsRow(
                icon: "pause.circle",
                title: "Monitor clipboard",
                detail: "Turn off to pause capturing new clipboard items."
            ) {
                Toggle("", isOn: $settings.monitorEnabled)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.small)
            }
        }
    }

    private var dataCard: some View {
        SettingsCard(
            icon: "externaldrive",
            title: "Data",
            subtitle: "Everything stays on this Mac. Nothing is uploaded."
        ) {
            SettingsRow(
                icon: "folder",
                title: "Storage location",
                detail: state.storageDescription
            ) {
                Button {
                    state.revealDataFolder()
                } label: {
                    Label("Reveal", systemImage: "finder")
                }
                .buttonStyle(SecondaryActionButtonStyle())
                .controlSize(.small)
            }

            SettingsDivider()

            SettingsRow(
                icon: "square.and.arrow.up.on.square",
                title: "Backup",
                detail: "Export or import a JSON archive including images and snippets."
            ) {
                HStack(spacing: 7) {
                    Button {
                        state.exportBackup()
                    } label: {
                        Label("Export…", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(SecondaryActionButtonStyle())
                    .controlSize(.small)

                    Button {
                        state.importBackup()
                    } label: {
                        Label("Import…", systemImage: "square.and.arrow.down")
                    }
                    .buttonStyle(SecondaryActionButtonStyle())
                    .controlSize(.small)
                }
            }

            SettingsDivider()

            SettingsRow(
                icon: "trash",
                title: "Clear history",
                detail: "Remove clipboard history while optionally keeping pinned items."
            ) {
                Button(role: .destructive) {
                    showClearConfirm = true
                } label: {
                    Label("Clear…", systemImage: "trash")
                }
                .buttonStyle(SecondaryActionButtonStyle())
                .controlSize(.small)
            }
        }
    }

    private var aboutCard: some View {
        SettingsCard(
            icon: "info.circle",
            title: "About",
            subtitle: "A small local-first utility for macOS."
        ) {
            HStack(alignment: .top, spacing: 12) {
                BrandMark(size: 46)
                VStack(alignment: .leading, spacing: 5) {
                    Text("Clipboard Manager")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                    Text("Version \(AppInfo.version) (\(AppInfo.build)) · Universal Intel + Apple Silicon")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                    Text("Clipboard history, OCR search, snippets, and text transforms. No account, no cloud, no App Store.")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
            }
            .padding(.vertical, 2)
        }
    }
}

struct SettingsCard<Content: View>: View {
    let icon: String
    let title: String
    let subtitle: String
    let content: Content

    init(icon: String, title: String, subtitle: String, @ViewBuilder content: () -> Content) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 9) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Theme.accent.opacity(0.11))
                    Image(systemName: icon)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                }
                .frame(width: 25, height: 25)

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                    Text(subtitle)
                        .font(.system(size: 9.5))
                        .foregroundStyle(.tertiary)
                }
                Spacer()
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 10)

            Divider().opacity(0.5)

            VStack(spacing: 0) {
                content
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 3)
        }
        .cardStyle(cornerRadius: 13)
    }
}

struct SettingsRow<Accessory: View>: View {
    let icon: String
    let title: String
    let detail: String
    let accessory: Accessory

    init(
        icon: String,
        title: String,
        detail: String,
        @ViewBuilder accessory: () -> Accessory
    ) {
        self.icon = icon
        self.title = title
        self.detail = detail
        self.accessory = accessory()
    }

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 20, height: 20)
                .background(Theme.subtle.opacity(0.55), in: RoundedRectangle(cornerRadius: 5))

            VStack(alignment: .leading, spacing: 1.5) {
                Text(title)
                    .font(.system(size: 11.5, weight: .semibold))
                Text(detail)
                    .font(.system(size: 9.5))
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            accessory
                .fixedSize()
        }
        .padding(.vertical, 7)
    }
}

struct SettingsDivider: View {
    var body: some View {
        Divider()
            .opacity(0.45)
            .padding(.leading, 30)
    }
}
