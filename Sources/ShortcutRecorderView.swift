import SwiftUI
import AppKit
import Carbon.HIToolbox

struct ShortcutRecorder: NSViewRepresentable {
    var displayText: String
    var onCaptured: (GlobalShortcut) -> Void
    var onInvalidCapture: () -> Void

    func makeNSView(context: Context) -> ShortcutRecorderView {
        let view = ShortcutRecorderView()
        view.displayText = displayText
        view.onCaptured = onCaptured
        view.onInvalidCapture = onInvalidCapture
        return view
    }

    func updateNSView(_ nsView: ShortcutRecorderView, context: Context) {
        nsView.displayText = displayText
        nsView.onCaptured = onCaptured
        nsView.onInvalidCapture = onInvalidCapture
    }
}

final class ShortcutRecorderView: NSView {
    private let label = NSTextField(labelWithString: "")
    private var recording = false

    var displayText: String = "" {
        didSet {
            if !recording {
                label.stringValue = displayText.isEmpty ? "Click to record" : displayText
            }
        }
    }

    var onCaptured: ((GlobalShortcut) -> Void)?
    var onInvalidCapture: (() -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerRadius = 7
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.separatorColor.cgColor
        layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        focusRingType = .none
        label.translatesAutoresizingMaskIntoConstraints = false
        label.alignment = .center
        label.font = .systemFont(ofSize: 12, weight: .medium)
        label.textColor = .labelColor
        addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            label.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
        label.stringValue = displayText
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var acceptsFirstResponder: Bool { true }

    override func becomeFirstResponder() -> Bool {
        true
    }

    override func resignFirstResponder() -> Bool {
        recording = false
        label.stringValue = displayText.isEmpty ? "Click to record" : displayText
        layer?.borderColor = NSColor.separatorColor.cgColor
        layer?.borderWidth = 1
        return true
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        recording = true
        label.stringValue = "Press shortcut…"
        layer?.borderColor = NSColor.controlAccentColor.cgColor
        layer?.borderWidth = 2
    }

    override func keyDown(with event: NSEvent) {
        guard recording else {
            super.keyDown(with: event)
            return
        }
        if event.keyCode == 53 {
            window?.makeFirstResponder(nil)
            return
        }
        let keyCode = UInt32(event.keyCode)
        guard !KeyCodeMap.isModifierKey(keyCode) else { return }
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let modifiers = KeyCodeMap.carbonModifiers(from: flags)
        guard modifiers != 0 else {
            NSSound.beep()
            onInvalidCapture?()
            return
        }
        let shortcut = GlobalShortcut(
            keyCode: keyCode,
            carbonModifiers: modifiers,
            display: KeyCodeMap.display(keyCode: keyCode, modifiers: modifiers)
        )
        displayText = shortcut.display
        onCaptured?(shortcut)
        window?.makeFirstResponder(nil)
    }
}
