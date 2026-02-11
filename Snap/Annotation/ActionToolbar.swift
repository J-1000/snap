import AppKit

final class ActionToolbar: NSView {
    var onCopy: (() -> Void)?
    var onSave: (() -> Void)?
    var onSaveAs: (() -> Void)?
    var onClose: (() -> Void)?

    static let height: CGFloat = 40

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupViews()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    private func setupViews() {
        let visualEffect = NSVisualEffectView(frame: bounds)
        visualEffect.material = .hudWindow
        visualEffect.state = .active
        visualEffect.autoresizingMask = [.width, .height]
        addSubview(visualEffect)

        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false

        let copyButton = makeButton(title: "Copy", symbol: "doc.on.doc", key: "c", action: #selector(copyTapped))
        let saveButton = makeButton(title: "Save", symbol: "square.and.arrow.down", key: "s", action: #selector(saveTapped))
        let saveAsButton = makeButton(title: "Save As…", symbol: "square.and.arrow.down.on.square", key: "S", action: #selector(saveAsTapped))
        let closeButton = makeButton(title: "Close", symbol: "xmark", key: "\u{1b}", action: #selector(closeTapped))
        closeButton.keyEquivalentModifierMask = []

        stack.addArrangedSubview(copyButton)
        stack.addArrangedSubview(saveButton)
        stack.addArrangedSubview(saveAsButton)
        stack.addArrangedSubview(NSView()) // spacer
        stack.addArrangedSubview(closeButton)

        visualEffect.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: visualEffect.leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: visualEffect.trailingAnchor, constant: -12),
            stack.centerYAnchor.constraint(equalTo: visualEffect.centerYAnchor),
        ])
    }

    private func makeButton(title: String, symbol: String, key: String, action: Selector) -> NSButton {
        let button = NSButton(title: title, target: self, action: action)
        if let img = NSImage(systemSymbolName: symbol, accessibilityDescription: title) {
            button.image = img
            button.imagePosition = .imageLeading
        }
        button.bezelStyle = .recessed
        button.isBordered = true
        button.keyEquivalent = key
        button.keyEquivalentModifierMask = key == "\u{1b}" ? [] : [.command]
        return button
    }

    @objc private func copyTapped() { onCopy?() }
    @objc private func saveTapped() { onSave?() }
    @objc private func saveAsTapped() { onSaveAs?() }
    @objc private func closeTapped() { onClose?() }
}
