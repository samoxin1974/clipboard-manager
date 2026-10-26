import SwiftUI
import AppKit

enum Theme {
    static let accent = Color(red: 0.04, green: 0.60, blue: 0.56)
    static let accentBright = Color(red: 0.12, green: 0.79, blue: 0.82)
    static let warm = Color(red: 0.96, green: 0.49, blue: 0.13)
    static let rose = Color(red: 0.91, green: 0.35, blue: 0.48)
    static let violet = Color(red: 0.55, green: 0.42, blue: 0.93)
    static let amber = Color(red: 0.95, green: 0.68, blue: 0.20)

    static let panel = Color(nsColor: .windowBackgroundColor)
    static let subtle = Color(nsColor: .controlBackgroundColor)
    static let card = Color(nsColor: .textBackgroundColor)
    static let separator = Color(nsColor: .separatorColor)

    static let accentGradient = LinearGradient(
        colors: [accent, accentBright],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static func tint(for kind: ClipKind) -> Color {
        switch kind {
        case .text: return accent
        case .richText: return violet
        case .link: return Color(red: 0.20, green: 0.52, blue: 0.96)
        case .image: return rose
        case .file: return amber
        case .color: return warm
        }
    }

    static func gradient(for kind: ClipKind) -> LinearGradient {
        let color = tint(for: kind)
        return LinearGradient(
            colors: [color.opacity(0.95), color.opacity(0.62)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

struct PanelBackground: View {
    var body: some View {
        ZStack {
            VisualEffectView(material: .underWindowBackground, blendingMode: .behindWindow)
            LinearGradient(
                colors: [
                    Theme.accent.opacity(0.10),
                    Theme.accentBright.opacity(0.03),
                    Color.clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            LinearGradient(
                colors: [Color.clear, Theme.warm.opacity(0.035)],
                startPoint: .top,
                endPoint: .bottomTrailing
            )
        }
        .ignoresSafeArea()
    }
}

struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

struct BrandMark: View {
    var size: CGFloat = 30

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.30, style: .continuous)
                .fill(Theme.accentGradient)
            RoundedRectangle(cornerRadius: size * 0.30, style: .continuous)
                .strokeBorder(Color.white.opacity(0.20), lineWidth: 1)
            Image(systemName: "doc.on.clipboard.fill")
                .font(.system(size: size * 0.47, weight: .semibold))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
        .shadow(color: Theme.accent.opacity(0.35), radius: size * 0.20, y: size * 0.08)
    }
}

struct KindArtwork: View {
    let kind: ClipKind
    var size: CGFloat = 38
    var image: NSImage?

    var body: some View {
        ZStack {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size, height: size)
                    .clipped()
                LinearGradient(
                    colors: [Color.black.opacity(0.02), Color.black.opacity(0.24)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                Image(systemName: kind.symbolName)
                    .font(.system(size: size * 0.24, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(size * 0.12)
                    .background(.black.opacity(0.34), in: Circle())
                    .frame(width: size, height: size, alignment: .bottomTrailing)
            } else {
                RoundedRectangle(cornerRadius: size * 0.27, style: .continuous)
                    .fill(Theme.gradient(for: kind))
                Image(systemName: kind.symbolName)
                    .font(.system(size: size * 0.40, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.96))
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.27, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: size * 0.27, style: .continuous)
                .strokeBorder(Color.white.opacity(0.16), lineWidth: 1)
        )
    }
}

struct SourceIcon: View {
    let bundleID: String?
    var size: CGFloat = 14

    var body: some View {
        if let image = AppIconCache.image(for: bundleID) {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
        } else {
            Image(systemName: "app.dashed")
                .font(.system(size: size * 0.82, weight: .medium))
                .foregroundStyle(.tertiary)
                .frame(width: size, height: size)
        }
    }
}

@MainActor
enum AppIconCache {
    private static var cache: [String: NSImage] = [:]

    static func image(for bundleID: String?) -> NSImage? {
        guard let bundleID, !bundleID.isEmpty else { return nil }
        if let cached = cache[bundleID] { return cached }
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            return nil
        }
        let image = NSWorkspace.shared.icon(forFile: url.path)
        cache[bundleID] = image
        return image
    }
}

struct TypePill: View {
    let kind: ClipKind
    var compact = false

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: kind.symbolName)
                .font(.system(size: compact ? 8.5 : 9.5, weight: .bold))
            Text(kind.title)
                .font(.system(size: compact ? 9.5 : 10.5, weight: .semibold))
        }
        .foregroundStyle(Theme.tint(for: kind))
        .padding(.horizontal, compact ? 6 : 8)
        .padding(.vertical, compact ? 2.5 : 4)
        .background(Theme.tint(for: kind).opacity(0.12), in: Capsule())
        .overlay(Capsule().strokeBorder(Theme.tint(for: kind).opacity(0.16), lineWidth: 0.8))
    }
}

struct KeyHint: View {
    let key: String
    let label: String

    var body: some View {
        HStack(spacing: 4) {
            Text(key)
                .font(.system(size: 9.5, weight: .bold, design: .rounded))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(Theme.subtle.opacity(0.85), in: RoundedRectangle(cornerRadius: 4))
                .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(Theme.separator.opacity(0.7), lineWidth: 0.6))
            Text(label)
                .font(.system(size: 9.5, weight: .medium))
                .foregroundStyle(.tertiary)
        }
    }
}

struct IconButton: View {
    let symbol: String
    var help: String = ""
    var tint: Color = .secondary
    var active = false
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(active ? Theme.accent : tint)
                .frame(width: 29, height: 29)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(hovering || active ? Theme.subtle.opacity(0.9) : Color.clear)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help(help)
    }
}

struct PrimaryActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Theme.accentGradient)
                    .shadow(color: Theme.accent.opacity(0.22), radius: 5, y: 2)
            )
            .opacity(configuration.isPressed ? 0.72 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct SecondaryActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Theme.subtle.opacity(0.9))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .strokeBorder(Theme.separator.opacity(0.7), lineWidth: 0.8)
            )
            .opacity(configuration.isPressed ? 0.72 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct ToastBanner: View {
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Theme.accentBright)
            Text(text)
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(Color.white.opacity(0.12), lineWidth: 0.8))
        .shadow(color: Color.black.opacity(0.18), radius: 12, y: 4)
    }
}

struct EmptyState: View {
    let symbol: String
    let title: String
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(Theme.accent.opacity(0.10))
                    .frame(width: 58, height: 58)
                Image(systemName: symbol)
                    .font(.system(size: 23, weight: .medium))
                    .foregroundStyle(Theme.accent)
            }
            Text(title)
                .font(.system(size: 13.5, weight: .semibold, design: .rounded))
            Text(message)
                .font(.system(size: 11.5))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 260)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(SecondaryActionButtonStyle())
                    .padding(.top, 3)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(30)
    }
}

extension View {
    func cardStyle(cornerRadius: CGFloat = 13) -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Theme.card.opacity(0.58))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Theme.separator.opacity(0.55), lineWidth: 0.8)
            )
    }
}
