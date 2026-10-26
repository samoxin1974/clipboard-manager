import SwiftUI
import AppKit

struct SnippetsView: View {
    @EnvironmentObject private var state: AppState
    @State private var draftTitle = ""
    @State private var draftBody = ""
    @State private var editingID: String?
    @State private var dirty = false
    @State private var saveWorkItem: DispatchWorkItem?
    @FocusState private var titleFocused: Bool

    var body: some View {
        HSplitView {
            snippetList
                .frame(minWidth: 300, idealWidth: 340, maxWidth: 440)
            editor
                .frame(minWidth: 390, maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear {
            if let snippet = state.selectedSnippet {
                loadDraft(snippet)
            } else {
                startNew()
            }
        }
        .onChange(of: state.selectedSnippetID) { _, newID in
            guard newID != editingID else { return }
            if dirty {
                commitDraft(allowCreate: false, notify: false)
            }
            if let snippet = state.snippets.first(where: { $0.id == newID }) {
                loadDraft(snippet)
            } else {
                clearDraft()
            }
        }
        .onChange(of: state.saveSnippetRequest) { _, _ in
            commitDraft(allowCreate: true, notify: true)
        }
        .onChange(of: state.copySnippetRequest) { _, _ in
            copyCurrent()
        }
        .onChange(of: state.pasteSnippetRequest) { _, _ in
            pasteCurrent()
        }
        .onChange(of: titleFocused) { _, focused in
            state.snippetTitleFocused = focused
        }
        .onDisappear {
            commitDraft(allowCreate: true, notify: false)
        }
    }

    private var snippetList: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Snippets")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                    Text("Reusable text, one shortcut away")
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundStyle(.tertiary)
                }
                Spacer()
                Button {
                    startNew()
                } label: {
                    Label("New", systemImage: "plus")
                }
                .buttonStyle(SecondaryActionButtonStyle())
                .controlSize(.small)
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 10)

            Divider().opacity(0.5)

            if state.filteredSnippets.isEmpty {
                EmptyState(
                    symbol: "text.badge.plus",
                    title: state.snippets.isEmpty ? "No snippets yet" : "No matching snippets",
                    message: state.snippets.isEmpty
                        ? "Save frequently used text here and paste it without opening another app."
                        : "Try a different search or create a new snippet.",
                    actionTitle: state.snippets.isEmpty ? "Create a Snippet" : nil,
                    action: state.snippets.isEmpty ? { startNew() } : nil
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 5) {
                        ForEach(state.filteredSnippets) { snippet in
                            SnippetRow(snippet: snippet, selected: snippet.id == editingID)
                                .onTapGesture {
                                    select(snippet)
                                }
                                .contextMenu {
                                    Button("Paste") { paste(snippet) }
                                    Button("Copy") { state.copySnippet(snippet) }
                                    Divider()
                                    Button("Delete", role: .destructive) {
                                        state.deleteSnippet(snippet)
                                    }
                                }
                        }
                    }
                    .padding(9)
                }
            }
        }
        .frame(maxHeight: .infinity)
        .background(Theme.panel.opacity(0.38))
    }

    private var editor: some View {
        VStack(spacing: 0) {
            HStack(spacing: 9) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(editingID == nil ? "New Snippet" : "Edit Snippet")
                        .font(.system(size: 12.5, weight: .bold, design: .rounded))
                    Text(dirty ? "Saving automatically…" : "Saved automatically")
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundStyle(dirty ? Theme.warm : Color.secondary.opacity(0.7))
                }

                Spacer()

                Button {
                    commitDraft(allowCreate: true, notify: true)
                } label: {
                    Label("Save", systemImage: "checkmark")
                }
                .buttonStyle(SecondaryActionButtonStyle())
                .controlSize(.small)
                .disabled(!dirty && editingID == nil)

                Button {
                    pasteCurrent()
                } label: {
                    Label("Paste", systemImage: "arrow.turn.down.left")
                }
                .buttonStyle(PrimaryActionButtonStyle())
                .controlSize(.small)
                .keyboardShortcut(.return, modifiers: [.command])
                .disabled(draftBody.isEmpty && draftTitle.trimmed.isEmpty)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Divider().opacity(0.5)

            VStack(alignment: .leading, spacing: 10) {
                TextField("Snippet title", text: $draftTitle)
                    .textFieldStyle(.plain)
                    .font(.system(size: 19, weight: .bold, design: .rounded))
                    .focused($titleFocused)
                    .onChange(of: draftTitle) { _, _ in scheduleSave() }

                HStack(spacing: 6) {
                    Text(editingID == nil ? "Draft" : "Editing")
                    Text("·")
                    Text("\(draftBody.count) characters")
                    Spacer()
                    if editingID != nil {
                        Button {
                            copyCurrent()
                        } label: {
                            Label("Copy", systemImage: "doc.on.doc")
                        }
                        .buttonStyle(.plain)
                        .font(.system(size: 9.5, weight: .semibold))
                        .foregroundStyle(.secondary)
                    }
                    Button {
                        deleteCurrent()
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundStyle(editingID == nil ? Color.secondary.opacity(0.4) : Theme.rose)
                    .disabled(editingID == nil)
                }
                .font(.system(size: 9.5, weight: .medium))
                .foregroundStyle(.tertiary)

                ZStack(alignment: .topLeading) {
                    if draftBody.isEmpty {
                        Text("Write reusable text here — signatures, replies, code fragments, prompts, anything you paste often.")
                            .font(.system(size: 12.5))
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 11)
                            .allowsHitTesting(false)
                    }
                    TextEditor(text: $draftBody)
                        .font(.system(size: 12.5, design: .monospaced))
                        .scrollContentBackground(.hidden)
                        .padding(7)
                        .onChange(of: draftBody) { _, _ in scheduleSave() }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Theme.card.opacity(0.50), in: RoundedRectangle(cornerRadius: 11))
                .overlay(
                    RoundedRectangle(cornerRadius: 11)
                        .strokeBorder(Theme.separator.opacity(0.65), lineWidth: 0.8)
                )

                HStack(spacing: 5) {
                    Image(systemName: "lock.shield")
                    Text("Snippets stay in your local app data folder.")
                    Spacer()
                    Text("⌘S to save · ⌘Return to paste")
                }
                .font(.system(size: 9.3, weight: .medium))
                .foregroundStyle(.tertiary)
            }
            .padding(14)
        }
    }

    private func select(_ snippet: Snippet) {
        if dirty {
            commitDraft(allowCreate: true, notify: false)
        }
        guard snippet.id != editingID else { return }
        state.selectedSnippetID = snippet.id
    }

    private func loadDraft(_ snippet: Snippet) {
        saveWorkItem?.cancel()
        editingID = snippet.id
        draftTitle = snippet.title
        draftBody = snippet.body
        dirty = false
    }

    private func clearDraft() {
        saveWorkItem?.cancel()
        editingID = nil
        draftTitle = ""
        draftBody = ""
        dirty = false
    }

    private func startNew() {
        commitDraft(allowCreate: true, notify: false)
        saveWorkItem?.cancel()
        editingID = nil
        draftTitle = ""
        draftBody = ""
        dirty = false
        state.selectedSnippetID = nil
        titleFocused = true
    }

    private func scheduleSave() {
        dirty = true
        saveWorkItem?.cancel()
        let item = DispatchWorkItem {
            commitDraft(allowCreate: true, notify: false)
        }
        saveWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.65, execute: item)
    }

    private func commitDraft(allowCreate: Bool, notify: Bool) {
        saveWorkItem?.cancel()
        saveWorkItem = nil

        guard dirty else {
            if notify { state.showToast("No changes to save") }
            return
        }

        if let editingID, let existing = state.snippets.first(where: { $0.id == editingID }) {
            if let updated = state.updateSnippet(
                existing,
                title: draftTitle,
                body: draftBody,
                notify: notify
            ) {
                self.editingID = updated.id
                draftTitle = updated.title
                draftBody = updated.body
                dirty = false
            }
            return
        }

        guard allowCreate else { return }
        guard !draftTitle.trimmed.isEmpty || !draftBody.trimmed.isEmpty else {
            if notify { state.showToast("Write something first") }
            return
        }

        if let created = state.createSnippet(
            title: draftTitle,
            body: draftBody,
            notify: notify
        ) {
            editingID = created.id
            draftTitle = created.title
            draftBody = created.body
            dirty = false
        }
    }

    private func pasteCurrent() {
        commitDraft(allowCreate: true, notify: false)
        guard let editingID,
              let snippet = state.snippets.first(where: { $0.id == editingID }) else {
            state.showToast("Write something first")
            return
        }
        state.pasteSnippet(snippet)
    }

    private func copyCurrent() {
        commitDraft(allowCreate: true, notify: false)
        guard let editingID,
              let snippet = state.snippets.first(where: { $0.id == editingID }) else { return }
        state.copySnippet(snippet)
    }

    private func deleteCurrent() {
        guard let editingID,
              let snippet = state.snippets.first(where: { $0.id == editingID }) else { return }
        saveWorkItem?.cancel()
        self.editingID = nil
        draftTitle = ""
        draftBody = ""
        dirty = false
        state.deleteSnippet(snippet)
    }

    private func paste(_ snippet: Snippet) {
        state.pasteSnippet(snippet)
    }
}

struct SnippetRow: View {
    let snippet: Snippet
    let selected: Bool
    @State private var hovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 5) {
                Image(systemName: "text.quote")
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundStyle(selected ? Theme.accent : Color.secondary.opacity(0.7))
                Text(snippet.title)
                    .font(.system(size: 11.5, weight: .semibold))
                    .lineLimit(1)
                Spacer(minLength: 2)
                Text(snippet.updatedAt.relativeDescription)
                    .font(.system(size: 8.8, weight: .medium))
                    .foregroundStyle(.tertiary)
            }
            Text(snippet.previewText)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(selected ? Theme.accent.opacity(0.14) : (hovering ? Theme.subtle.opacity(0.52) : Color.clear))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(selected ? Theme.accent.opacity(0.35) : Color.clear, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.10), value: hovering)
    }
}
