import SwiftUI
import AppKit

struct HistoryView: View {
    @EnvironmentObject private var state: AppState
    @FocusState private var searchFocused: Bool
    @State private var showClearConfirm = false

    var body: some View {
        ZStack(alignment: .bottom) {
            PanelBackground()

            VStack(spacing: 0) {
                header
                Divider().opacity(0.55)

                if state.mode == .history {
                    HSplitView {
                        historyList
                            .frame(minWidth: 330, idealWidth: 380, maxWidth: 500)
                        detailPane
                            .frame(minWidth: 390, maxWidth: .infinity, maxHeight: .infinity)
                    }
                } else {
                    SnippetsView()
                }

                Divider().opacity(0.55)
                footer
            }

            if let toast = state.toast {
                ToastBanner(text: toast)
                    .padding(.bottom, 46)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(10)
            }
        }
        .frame(minWidth: 800, minHeight: 520)
        .animation(.easeOut(duration: 0.18), value: state.toast)
        .onAppear {
            state.refreshAccessibilityStatus()
        }
        .onChange(of: state.focusSearchRequest) { _, _ in
            searchFocused = true
        }
        .onChange(of: state.mode) { _, _ in
            searchFocused = true
        }
        .onChange(of: searchFocused) { _, focused in
            state.searchFieldFocused = focused
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
            Text("Pinned items can be kept while the rest of your clipboard history is removed.")
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            HStack(spacing: 9) {
                BrandMark(size: 27)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Clipboard Manager")
                        .font(.system(size: 14.5, weight: .bold, design: .rounded))
                    Text(headerSubtitle)
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(.leading, 70)

            Spacer(minLength: 8)

            modeSwitcher

            SearchField(text: $state.searchText, focused: $searchFocused)
                .frame(width: 210)

            filterMenu
            monitoringButton
            overflowMenu
        }
        .padding(.horizontal, 14)
        .padding(.top, 9)
        .padding(.bottom, 9)
        .background(.ultraThinMaterial.opacity(0.55))
    }

    private var headerSubtitle: String {
        if !state.searchText.trimmed.isEmpty {
            let count = state.mode == .history ? state.filteredItems.count : state.filteredSnippets.count
            return "\(count) result\(count == 1 ? "" : "s") for “\(state.searchText.safePrefix(28))”"
        }
        if state.mode == .snippets {
            return "\(state.snippets.count) snippets · reusable text"
        }
        return "\(state.filteredItems.count) shown · \(state.pinnedCount) pinned"
    }

    private var modeSwitcher: some View {
        HStack(spacing: 2) {
            ForEach(PanelMode.allCases) { mode in
                Button {
                    withAnimation(.easeOut(duration: 0.16)) {
                        state.mode = mode
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: mode.symbolName)
                            .font(.system(size: 9.5, weight: .semibold))
                        Text(mode.title)
                            .font(.system(size: 10.5, weight: .semibold))
                    }
                    .foregroundStyle(state.mode == mode ? Theme.accent : Color.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4.5)
                    .background(
                        Capsule()
                            .fill(state.mode == mode ? Theme.accent.opacity(0.14) : Color.clear)
                    )
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background(Theme.subtle.opacity(0.72), in: Capsule())
        .overlay(Capsule().strokeBorder(Theme.separator.opacity(0.55), lineWidth: 0.7))
    }

    private var filterMenu: some View {
        Menu {
            Section("Type") {
                ForEach(HistoryFilter.allCases) { filter in
                    Button {
                        state.filter = filter
                        state.ensureSelectionVisible()
                    } label: {
                        if state.filter == filter {
                            Label(filter.title, systemImage: "checkmark")
                        } else {
                            Label(filter.title, systemImage: filter.symbolName)
                        }
                    }
                }
            }

            if !state.sourceOptions.isEmpty {
                Divider()
                Section("Source App") {
                    Button {
                        state.sourceFilter = nil
                        state.ensureSelectionVisible()
                    } label: {
                        if state.sourceFilter == nil {
                            Label("All Apps", systemImage: "checkmark")
                        } else {
                            Text("All Apps")
                        }
                    }
                    ForEach(state.sourceOptions) { option in
                        Button {
                            state.sourceFilter = option.bundleID
                            state.ensureSelectionVisible()
                        } label: {
                            if state.sourceFilter == option.bundleID {
                                Label(option.name, systemImage: "checkmark")
                            } else {
                                Text(option.name)
                            }
                        }
                    }
                }
            }
        } label: {
            Image(systemName: "line.3.horizontal.decrease.circle")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(hasActiveFilter ? Theme.accent : Color.secondary)
                .frame(width: 29, height: 29)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(hasActiveFilter ? Theme.accent.opacity(0.12) : Color.clear)
                )
                .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Filter history")
    }

    private var hasActiveFilter: Bool {
        state.filter != .all || state.sourceFilter != nil
    }

    private var monitoringButton: some View {
        IconButton(
            symbol: state.settings.monitorEnabled ? "pause.fill" : "play.fill",
            help: state.settings.monitorEnabled ? "Pause clipboard monitoring" : "Resume clipboard monitoring",
            tint: state.settings.monitorEnabled ? .secondary : Theme.warm,
            active: !state.settings.monitorEnabled
        ) {
            state.toggleMonitoring()
            state.showToast(state.settings.monitorEnabled ? "Clipboard monitoring resumed" : "Clipboard monitoring paused")
        }
    }

    private var overflowMenu: some View {
        Menu {
            Button {
                state.captureCurrentClipboard()
            } label: {
                Label("Capture Current Clipboard", systemImage: "arrow.down.doc")
            }
            Divider()
            Button {
                state.exportBackup()
            } label: {
                Label("Export Backup…", systemImage: "square.and.arrow.up")
            }
            Button {
                state.importBackup()
            } label: {
                Label("Import Backup…", systemImage: "square.and.arrow.down")
            }
            Divider()
            Button(role: .destructive) {
                showClearConfirm = true
            } label: {
                Label("Clear History…", systemImage: "trash")
            }
            Divider()
            Button {
                state.openSettings()
            } label: {
                Label("Settings…", systemImage: "gearshape")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.system(size: 13.5, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 29, height: 29)
                .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("More actions")
    }

    private var historyList: some View {
        Group {
            if state.filteredItems.isEmpty {
                EmptyState(
                    symbol: state.items.isEmpty ? "clipboard" : "line.3.horizontal.decrease.circle",
                    title: state.items.isEmpty ? "Nothing copied yet" : "No matching items",
                    message: state.items.isEmpty
                        ? "Copy something anywhere on your Mac and it will appear here instantly."
                        : "Try another search or reset the filters to see more history."
                )
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 5) {
                            ForEach(Array(state.filteredItems.enumerated()), id: \.element.id) { index, item in
                                HistoryRow(item: item, index: index)
                                    .id(item.id)
                                    .onTapGesture {
                                        state.selectedItemID = item.id
                                    }
                                    .simultaneousGesture(
                                        TapGesture(count: 2).onEnded {
                                            state.selectedItemID = item.id
                                            state.paste(item)
                                        }
                                    )
                                    .contextMenu {
                                        itemMenu(item)
                                    }
                            }
                        }
                        .padding(9)
                    }
                    .onChange(of: state.selectedItemID) { _, id in
                        guard let id else { return }
                        withAnimation(.easeOut(duration: 0.16)) {
                            proxy.scrollTo(id, anchor: .center)
                        }
                    }
                }
            }
        }
        .frame(maxHeight: .infinity)
        .background(Theme.panel.opacity(0.38))
    }

    private var detailPane: some View {
        Group {
            if let item = state.selectedItem {
                ItemDetailView(item: item)
                    .id(item.id)
            } else {
                EmptyState(
                    symbol: "rectangle.on.rectangle",
                    title: "Select an item",
                    message: "Choose something from the history to preview it, copy it, or paste it into your previous app."
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.panel.opacity(0.20))
    }

    private var footer: some View {
        HStack(spacing: 12) {
            if state.mode == .history {
                KeyHint(key: "↵", label: "Paste")
                KeyHint(key: "⌘C", label: "Copy")
                KeyHint(key: "⌘P", label: "Pin")
                KeyHint(key: "⌫", label: "Delete")
            } else {
                KeyHint(key: "↵", label: "Paste")
                KeyHint(key: "⌘S", label: "Save")
                KeyHint(key: "⌫", label: "Delete")
            }
            KeyHint(key: "esc", label: "Close")

            Spacer()

            if !state.accessibilityTrusted {
                Button {
                    state.requestAccessibilityPermission()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "hand.raised.fill")
                        Text("Enable instant paste")
                    }
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundStyle(Theme.warm)
                }
                .buttonStyle(.plain)
                .help("Accessibility permission is required to send ⌘V automatically")
            }

            Text(state.storageDescription)
                .font(.system(size: 9.5, weight: .medium))
                .foregroundStyle(.tertiary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(.horizontal, 14)
        .frame(height: 31)
        .background(.ultraThinMaterial.opacity(0.5))
    }

    @ViewBuilder
    private func itemMenu(_ item: ClipItem) -> some View {
        Button("Paste") { state.paste(item) }
        Button("Copy") { state.copy(item) }
        if item.kind.isTextual {
            Button("Paste as Plain Text") { state.paste(item, variant: .plainText) }
            Button("Copy as Plain Text") { state.copy(item, asPlainText: true) }
            Button("Save as Snippet") {
                state.selectedItemID = item.id
                state.saveSelectedAsSnippet()
            }
        }
        Divider()
        Button(item.pinned ? "Unpin" : "Pin") { state.togglePin(item) }
        if item.kind == .image {
            Button("Save Image…") { state.saveImage(item) }
        }
        if item.kind == .link, let url = linkURL(for: item) {
            Button("Open Link") { NSWorkspace.shared.open(url) }
        }
        if item.kind == .file {
            Button("Reveal in Finder") {
                let urls = item.filePaths.map { URL(fileURLWithPath: $0) }
                NSWorkspace.shared.activateFileViewerSelecting(urls)
            }
        }
        Divider()
        Button("Delete", role: .destructive) { state.delete(item) }
    }
}

struct SearchField: View {
    @Binding var text: String
    var focused: FocusState<Bool>.Binding

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(focused.wrappedValue ? Theme.accent : Color.secondary)
            TextField("Search clipboard…", text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 11.5))
                .focused(focused)
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 10.5))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 9)
        .frame(height: 29)
        .background(Theme.subtle.opacity(0.78), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(
                    focused.wrappedValue ? Theme.accent.opacity(0.55) : Theme.separator.opacity(0.6),
                    lineWidth: focused.wrappedValue ? 1.2 : 0.7
                )
        )
        .animation(.easeOut(duration: 0.12), value: focused.wrappedValue)
    }
}

struct HistoryRow: View {
    @EnvironmentObject private var state: AppState
    let item: ClipItem
    let index: Int
    @State private var hovering = false

    private var isSelected: Bool {
        state.selectedItemID == item.id
    }

    var body: some View {
        HStack(spacing: 9) {
            quickIndex

            KindArtwork(
                kind: item.kind,
                size: 37,
                image: item.kind == .image ? item.imageFileName.flatMap { state.imageStore.image(named: $0) } : nil
            )

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    Text(item.titleText)
                        .font(.system(size: 12, weight: .semibold))
                        .lineLimit(1)
                    if item.pinned {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(Theme.warm)
                    }
                    Spacer(minLength: 2)
                    Text(item.formattedDate)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }

                Text(item.listPreview.isEmpty ? " " : item.listPreview)
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .opacity(item.listPreview.isEmpty ? 0 : 1)

                HStack(spacing: 4) {
                    SourceIcon(bundleID: item.sourceBundleID, size: 10.5)
                    Text(item.sourceDisplayName)
                        .lineLimit(1)
                    Text("·")
                    Text(item.kind.title)
                    if item.isOCRSearchable {
                        Text("OCR")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(Theme.accent)
                            .padding(.horizontal, 3.5)
                            .padding(.vertical, 1)
                            .background(Theme.accent.opacity(0.12), in: Capsule())
                    }
                }
                .font(.system(size: 9.2, weight: .medium))
                .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isSelected ? Theme.accent.opacity(0.14) : (hovering ? Theme.subtle.opacity(0.52) : Color.clear))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(isSelected ? Theme.accent.opacity(0.38) : Color.clear, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.10), value: hovering)
    }

    @ViewBuilder
    private var quickIndex: some View {
        if index < 9 {
            Text("\(index + 1)")
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .foregroundStyle(isSelected ? Theme.accent : Color.secondary.opacity(0.7))
                .frame(width: 15, height: 18)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(isSelected ? Theme.accent.opacity(0.12) : Theme.subtle.opacity(0.4))
                )
        } else {
            Spacer().frame(width: 15)
        }
    }
}

func linkURL(for item: ClipItem) -> URL? {
    guard let text = item.plainText else { return nil }
    return URL(string: URLTools.normalizedURLString(text))
}
