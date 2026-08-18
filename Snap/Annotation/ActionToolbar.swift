import AppKit

final class ActionToolbar: NSView {
    var onCopy: (() -> Void)?
    var onSave: (() -> Void)?
    var onSaveAs: (() -> Void)?
    var onReverseSearch: (() -> Void)?
    var onPrint: (() -> Void)?
    var onShare: (() -> Void)?
    var onCrop: (() -> Void)?
    var onClearCrop: (() -> Void)?
    var onZoomOut: (() -> Void)?
    var onZoomToFit: (() -> Void)?
    var onZoomIn: (() -> Void)?
    var onClose: (() -> Void)?

    static let height: CGFloat = 40
    /// Enough room for output actions plus crop and zoom controls.
    static let minimumWidth: CGFloat = 760

    private let cropButton = NSButton()
    private let clearCropButton = NSButton()

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
        let searchButton = makeButton(title: "Search", symbol: "magnifyingglass", key: "g", action: #selector(reverseSearchTapped))
        let printButton = makeButton(title: "Print", symbol: "printer", key: "p", action: #selector(printTapped))
        let shareButton = makeButton(title: "Share", symbol: "square.and.arrow.up", key: "", action: #selector(shareTapped))
        let closeButton = makeButton(title: "Close", symbol: "xmark", key: "\u{1b}", action: #selector(closeTapped))
        closeButton.keyEquivalentModifierMask = []

        configureIconButton(cropButton, symbol: "crop", label: "Crop", action: #selector(cropTapped))
        cropButton.setButtonType(.pushOnPushOff)
        configureIconButton(
            clearCropButton,
            symbol: "arrow.counterclockwise",
            label: "Clear Crop",
            action: #selector(clearCropTapped)
        )
        clearCropButton.isEnabled = false
        let zoomOutButton = makeIconButton(
            symbol: "minus.magnifyingglass",
            label: "Zoom Out",
            action: #selector(zoomOutTapped)
        )
        let zoomFitButton = makeIconButton(
            symbol: "arrow.up.left.and.arrow.down.right",
            label: "Zoom to Fit",
            action: #selector(zoomToFitTapped)
        )
        let zoomInButton = makeIconButton(
            symbol: "plus.magnifyingglass",
            label: "Zoom In",
            action: #selector(zoomInTapped)
        )

        stack.addArrangedSubview(copyButton)
        stack.addArrangedSubview(saveButton)
        stack.addArrangedSubview(saveAsButton)
        stack.addArrangedSubview(searchButton)
        stack.addArrangedSubview(printButton)
        stack.addArrangedSubview(shareButton)
        stack.addArrangedSubview(cropButton)
        stack.addArrangedSubview(clearCropButton)
        stack.addArrangedSubview(zoomOutButton)
        stack.addArrangedSubview(zoomFitButton)
        stack.addArrangedSubview(zoomInButton)
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

    private func makeIconButton(symbol: String, label: String, action: Selector) -> NSButton {
        let button = NSButton()
        configureIconButton(button, symbol: symbol, label: label, action: action)
        return button
    }

    private func configureIconButton(_ button: NSButton, symbol: String, label: String, action: Selector) {
        button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: label)
        button.imagePosition = .imageOnly
        button.bezelStyle = .recessed
        button.isBordered = true
        button.toolTip = label
        button.setAccessibilityLabel(label)
        button.target = self
        button.action = action
    }

    func setCropState(active: Bool, hasCrop: Bool) {
        cropButton.state = active ? .on : .off
        clearCropButton.isEnabled = hasCrop
    }

    @objc private func copyTapped() { onCopy?() }
    @objc private func saveTapped() { onSave?() }
    @objc private func saveAsTapped() { onSaveAs?() }
    @objc private func reverseSearchTapped() { onReverseSearch?() }
    @objc private func printTapped() { onPrint?() }
    @objc private func shareTapped() { onShare?() }
    @objc private func cropTapped() { onCrop?() }
    @objc private func clearCropTapped() { onClearCrop?() }
    @objc private func zoomOutTapped() { onZoomOut?() }
    @objc private func zoomToFitTapped() { onZoomToFit?() }
    @objc private func zoomInTapped() { onZoomIn?() }
    @objc private func closeTapped() { onClose?() }
}
