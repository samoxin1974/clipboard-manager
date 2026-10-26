import SwiftUI
import AppKit

struct ItemDetailView: View {
    @EnvironmentObject private var state: AppState
    let item: ClipItem
    @State private var showRichPreview = true

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.5)

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    content
                    metadata
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Divider().opacity(0.5)
            actionBar
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            TypePill(kind: item.kind)
            if item.pinned {
                HStack(spacing: 3) {
                    Image(systemName: "pin.fill")
                    Text("Pinned")
                }
                .font(.system(size: 9.5, weight: .semibold))
                .foregroundStyle(Theme.warm)
                .padding(.horizontal, 7)
                .padding(.vertical, 3.5)
                .background(Theme.warm.opacity(0.10), in: Capsule())
            }

            Spacer(minLength: 4)

            SourceIcon(bundleID: item.sourceBundleID, size: 13)
            Text(item.sourceDisplayName)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Text("·")
                .foregroundStyle(.tertiary)
            Text(item.formattedDate)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private var content: some View {
        switch item.kind {
        case .text:
            textCard(showRich: false)
        case .richText:
            richTextCard
        case .link:
            linkCard
        case .image:
            imageCard
        case .file:
            fileCard
        case .color:
            colorCard
        }
    }

    private func textCard(showRich: Bool) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 6) {
                Label(item.kind.title, systemImage: item.kind.symbolName)
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(item.plainText?.count ?? 0) characters")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.tertiary)
            }

            if item.plainText?.isCodeLike == true {
                ScrollView(.horizontal, showsIndicators: false) {
                    Text(item.plainText ?? "")
                        .font(.system(size: 12, design: .monospaced))
                        .lineSpacing(2)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: true, vertical: false)
                }
            } else {
                Text(item.plainText ?? "")
                    .font(.system(size: 13.5))
                    .lineSpacing(4)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(14)
        .cardStyle()
    }

    private var richTextCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Label("Rich Text", systemImage: "textformat")
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                if item.htmlText != nil {
                    Picker("", selection: $showRichPreview) {
                        Text("Formatted").tag(true)
                        Text("Plain").tag(false)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 150)
                    .controlSize(.mini)
                }
            }

            if showRichPreview, let html = item.htmlText, !html.isEmpty {
                RichTextPreview(html: html)
                    .frame(minHeight: 220, maxHeight: 380)
                    .background(Theme.subtle.opacity(0.28), in: RoundedRectangle(cornerRadius: 9))
            } else {
                Text(item.plainText ?? "")
                    .font(.system(size: 13.5))
                    .lineSpacing(4)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(14)
        .cardStyle()
    }

    private var linkCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.blue.opacity(0.12))
                    Image(systemName: "link")
                        .font(.system(size: 21, weight: .semibold))
                        .foregroundStyle(Color.blue)
                }
                .frame(width: 48, height: 48)

                VStack(alignment: .leading, spacing: 3) {
                    Text(linkURL(for: item)?.host ?? "Link")
                        .font(.system(size: 14, weight: .semibold))
                    Text(item.plainText ?? "")
                        .font(.system(size: 10.5, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .lineLimit(3)
                }
                Spacer()
            }

            if let url = linkURL(for: item) {
                HStack(spacing: 8) {
                    Button {
                        NSWorkspace.shared.open(url)
                    } label: {
                        Label("Open Link", systemImage: "arrow.up.right.square")
                    }
                    .buttonStyle(PrimaryActionButtonStyle())

                    Button {
                        state.copy(item)
                    } label: {
                        Label("Copy Link", systemImage: "doc.on.doc")
                    }
                    .buttonStyle(SecondaryActionButtonStyle())
                }
            }
        }
        .padding(15)
        .cardStyle()
    }

    private var imageCard: some View {
        VStack(alignment: .leading, spacing: 11) {
            if let fileName = item.imageFileName,
               let image = state.imageStore.image(named: fileName) {
                ZStack {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(Theme.subtle.opacity(0.38))
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 360)
                        .padding(7)
                }
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .strokeBorder(Theme.separator.opacity(0.55), lineWidth: 0.8)
                )
            }

            HStack(spacing: 8) {
                if let width = item.imageWidth, let height = item.imageHeight {
                    Label("\(width) × \(height)", systemImage: "aspectratio")
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                Text(item.formattedSize)
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(.tertiary)
                Spacer()
                Button {
                    state.saveImage(item)
                } label: {
                    Label("Save Image…", systemImage: "square.and.arrow.down")
                }
                .buttonStyle(SecondaryActionButtonStyle())
            }

            if let ocr = item.ocrText, !ocr.isEmpty {
                VStack(alignment: .leading, spacing: 7) {
                    Label("Text found in image", systemImage: "text.viewfinder")
                        .font(.system(size: 9.5, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                    Text(ocr)
                        .font(.system(size: 12))
                        .lineSpacing(3)
                        .textSelection(.enabled)
                        .foregroundStyle(.secondary)
                }
                .padding(11)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.accent.opacity(0.07), in: RoundedRectangle(cornerRadius: 9))
                .overlay(
                    RoundedRectangle(cornerRadius: 9)
                        .strokeBorder(Theme.accent.opacity(0.13), lineWidth: 0.8)
                )
            }
        }
        .padding(14)
        .cardStyle()
    }

    private var fileCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("\(item.filePaths.count) file\(item.filePaths.count == 1 ? "" : "s")", systemImage: "folder")
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    let urls = item.filePaths.map { URL(fileURLWithPath: $0) }
                    NSWorkspace.shared.activateFileViewerSelecting(urls)
                } label: {
                    Label("Reveal", systemImage: "finder")
                }
                .buttonStyle(SecondaryActionButtonStyle())
                .controlSize(.small)
            }

            ForEach(item.filePaths, id: \.self) { path in
                FileDetailRow(path: path)
            }
        }
        .padding(14)
        .cardStyle()
    }

    private var colorCard: some View {
        let color = NSColor(hex: item.colorHex ?? "") ?? .clear
        return VStack(alignment: .leading, spacing: 12) {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(Color(nsColor: color))
                .frame(height: 150)
                .overlay(
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
                )

            HStack(spacing: 9) {
                Text(item.colorHex ?? "")
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .textSelection(.enabled)
                Spacer()
                Button {
                    state.copy(item)
                } label: {
                    Label("Copy Color", systemImage: "doc.on.doc")
                }
                .buttonStyle(SecondaryActionButtonStyle())
            }
        }
        .padding(14)
        .cardStyle()
    }

    private var metadata: some View {
        VStack(spacing: 0) {
            MetadataRow(title: "Captured", value: item.createdAt.formatted(date: .abbreviated, time: .shortened))
            Divider().opacity(0.5)
            MetadataRow(title: "Source", value: sourceDescription)
            Divider().opacity(0.5)
            MetadataRow(title: "Size", value: item.formattedSize)
            if let width = item.imageWidth, let height = item.imageHeight {
                Divider().opacity(0.5)
                MetadataRow(title: "Dimensions", value: "\(width) × \(height) pixels")
            }
            Divider().opacity(0.5)
            MetadataRow(title: "Content hash", value: item.contentHash.safePrefix(20) + "…", monospaced: true)
        }
        .padding(.horizontal, 12)
        .cardStyle(cornerRadius: 10)
    }

    private var sourceDescription: String {
        if let bundleID = item.sourceBundleID, !bundleID.isEmpty {
            return "\(item.sourceDisplayName) · \(bundleID)"
        }
        return item.sourceDisplayName
    }

    private var actionBar: some View {
        HStack(spacing: 7) {
            Button {
                state.paste(item)
            } label: {
                Label("Paste", systemImage: "arrow.turn.down.left")
            }
            .buttonStyle(PrimaryActionButtonStyle())
            .keyboardShortcut(.return, modifiers: [])
            .help("Paste into the previous app (Return)")

            Button {
                state.copy(item)
            } label: {
                Label("Copy", systemImage: "doc.on.doc")
            }
            .buttonStyle(SecondaryActionButtonStyle())
            .help("Copy to clipboard (⌘C)")

            Button {
                state.togglePin(item)
            } label: {
                Label(item.pinned ? "Unpin" : "Pin", systemImage: item.pinned ? "pin.slash" : "pin")
            }
            .buttonStyle(SecondaryActionButtonStyle())
            .help("Pin or unpin (⌘P)")

            if item.kind.isTextual {
                Menu {
                    ForEach(PasteVariant.allCases.filter { $0 != .normal }) { variant in
                        Button(variant.title) {
                            state.paste(item, variant: variant)
                        }
                    }
                } label: {
                    Label("Paste As", systemImage: "wand.and.stars")
                        .font(.system(size: 12, weight: .semibold))
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }

            Spacer(minLength: 2)

            Menu {
                if item.kind.isTextual {
                    Button {
                        state.copy(item, asPlainText: true)
                    } label: {
                        Label("Copy as Plain Text", systemImage: "textformat")
                    }
                    Button {
                        state.saveSelectedAsSnippet()
                    } label: {
                        Label("Save as Snippet", systemImage: "text.badge.plus")
                    }
                    Divider()
                }
                if item.kind == .image {
                    Button {
                        state.saveImage(item)
                    } label: {
                        Label("Save Image…", systemImage: "square.and.arrow.down")
                    }
                }
                if item.kind == .link, let url = linkURL(for: item) {
                    Button {
                        NSWorkspace.shared.open(url)
                    } label: {
                        Label("Open Link", systemImage: "arrow.up.right.square")
                    }
                }
                if item.kind == .file {
                    Button {
                        let urls = item.filePaths.map { URL(fileURLWithPath: $0) }
                        NSWorkspace.shared.activateFileViewerSelecting(urls)
                    } label: {
                        Label("Reveal in Finder", systemImage: "finder")
                    }
                }
                Divider()
                Button(role: .destructive) {
                    state.delete(item)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 29, height: 29)
                    .contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("More actions")

            IconButton(symbol: "trash", help: "Delete item", tint: .secondary) {
                state.delete(item)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(.ultraThinMaterial.opacity(0.52))
    }
}

struct MetadataRow: View {
    let title: String
    let value: String
    var monospaced = false

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(title)
                .font(.system(size: 9.5, weight: .medium))
                .foregroundStyle(.tertiary)
                .frame(width: 80, alignment: .leading)
            Text(value)
                .font(.system(size: 9.5, weight: .medium, design: monospaced ? .monospaced : .default))
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 7)
    }
}

struct FileDetailRow: View {
    let path: String

    private var url: URL { URL(fileURLWithPath: path) }
    private var exists: Bool { FileManager.default.fileExists(atPath: path) }

    var body: some View {
        HStack(spacing: 9) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: path))
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(url.lastPathComponent)
                    .font(.system(size: 11.5, weight: .semibold))
                    .lineLimit(1)
                Text(url.deletingLastPathComponent().path)
                    .font(.system(size: 9.2))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 4)

            if !exists {
                Text("Missing")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Theme.rose)
            }

            Button {
                NSWorkspace.shared.activateFileViewerSelecting([url])
            } label: {
                Image(systemName: "finder")
                    .font(.system(size: 11, weight: .semibold))
                    .frame(width: 24, height: 24)
                    .background(Theme.subtle.opacity(0.85), in: RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
            .help("Reveal in Finder")
            .disabled(!exists)
        }
        .padding(8)
        .background(Theme.subtle.opacity(0.36), in: RoundedRectangle(cornerRadius: 8))
    }
}

struct RichTextPreview: NSViewRepresentable {
    let html: String

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder

        guard let textView = scrollView.documentView as? NSTextView else {
            return scrollView
        }
        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.isRichText = true
        textView.importsGraphics = true
        textView.textContainerInset = NSSize(width: 4, height: 6)
        textView.isHorizontallyResizable = false
        textView.textContainer?.widthTracksTextView = true
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard context.coordinator.html != html,
              let textView = scrollView.documentView as? NSTextView else { return }
        context.coordinator.html = html

        let attributed = HTMLTools.attributedString(fromHTML: html)
            ?? NSAttributedString(string: "Rich text could not be rendered. Use Plain view instead.")
        let mutable = NSMutableAttributedString(attributedString: attributed)

        let isDark = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        if isDark {
            let fullRange = NSRange(location: 0, length: mutable.length)
            mutable.enumerateAttribute(.foregroundColor, in: fullRange, options: []) { value, range, _ in
                guard let color = value as? NSColor,
                      let rgb = color.usingColorSpace(.sRGB) else { return }
                let luminance = 0.2126 * rgb.redComponent + 0.7152 * rgb.greenComponent + 0.0722 * rgb.blueComponent
                if luminance < 0.32 {
                    mutable.addAttribute(.foregroundColor, value: NSColor.labelColor, range: range)
                }
            }
        }

        textView.textStorage?.setAttributedString(mutable)
        textView.scrollToBeginningOfDocument(nil)
    }

    final class Coordinator {
        var html: String?
    }
}
