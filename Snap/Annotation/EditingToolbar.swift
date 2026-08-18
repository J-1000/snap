import AppKit

final class EditingToolbar: NSView {
    var selectedTool: AnnotationType? {
        didSet { updateSelection() }
    }
    var selectedColor: NSColor = .systemRed {
        didSet { colorWell.color = selectedColor }
    }
    var selectedLineWidth: CGFloat = 2 {
        didSet { lineWidthPopup.selectItem(withTitle: "\(Int(selectedLineWidth)) px") }
    }
    var selectedFontSize: CGFloat = 16 {
        didSet { fontSizePopup.selectItem(withTitle: "\(Int(selectedFontSize)) pt") }
    }
    var onToolChanged: ((AnnotationType?) -> Void)?
    var onColorChanged: ((NSColor) -> Void)?
    var onLineWidthChanged: ((CGFloat) -> Void)?
    var onFontSizeChanged: ((CGFloat) -> Void)?
    var onUndo: (() -> Void)?
    var onRedo: (() -> Void)?

    static let width: CGFloat = 72
    /// Selection, eight tools, color controls, and both option popups without clipping.
    static let minimumHeight: CGFloat = 520

    private var toolButtons: [AnnotationType: NSButton] = [:]
    private let colorWell = NSColorWell()
    private let lineWidthPopup = NSPopUpButton()
    private let fontSizePopup = NSPopUpButton()
    private let undoButton = NSButton()
    private let redoButton = NSButton()
    private let selectionButton = NSButton()

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
        stack.orientation = .vertical
        stack.spacing = 4
        stack.alignment = .centerX
        stack.translatesAutoresizingMaskIntoConstraints = false

        selectionButton.bezelStyle = .recessed
        selectionButton.setButtonType(.pushOnPushOff)
        selectionButton.isBordered = true
        selectionButton.image = NSImage(
            systemSymbolName: "cursorarrow",
            accessibilityDescription: "Select and edit annotations"
        )
        selectionButton.toolTip = "Select / Move Annotations"
        selectionButton.target = self
        selectionButton.action = #selector(selectionTapped)
        selectionButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            selectionButton.widthAnchor.constraint(equalToConstant: 32),
            selectionButton.heightAnchor.constraint(equalToConstant: 32),
        ])
        stack.addArrangedSubview(selectionButton)

        // Tool buttons — one per annotation type, in declaration order.
        for tool in AnnotationType.allCases {
            let button = makeToolButton(tool: tool)
            toolButtons[tool] = button
            stack.addArrangedSubview(button)
        }

        let historyStack = NSStackView()
        historyStack.orientation = .horizontal
        historyStack.spacing = 4
        configureHistoryButton(
            undoButton,
            symbol: "arrow.uturn.backward",
            label: "Undo",
            action: #selector(undoTapped)
        )
        configureHistoryButton(
            redoButton,
            symbol: "arrow.uturn.forward",
            label: "Redo",
            action: #selector(redoTapped)
        )
        historyStack.addArrangedSubview(undoButton)
        historyStack.addArrangedSubview(redoButton)
        stack.addArrangedSubview(historyStack)

        // Divider
        let divider = NSBox()
        divider.boxType = .separator
        divider.translatesAutoresizingMaskIntoConstraints = false
        stack.addArrangedSubview(divider)
        NSLayoutConstraint.activate([
            divider.widthAnchor.constraint(equalToConstant: 28),
        ])

        // Color well
        colorWell.color = selectedColor
        colorWell.translatesAutoresizingMaskIntoConstraints = false
        colorWell.target = self
        colorWell.action = #selector(colorChanged)
        colorWell.setAccessibilityLabel("Custom annotation color")
        if #available(macOS 13.0, *) {
            colorWell.colorWellStyle = .minimal
        }
        stack.addArrangedSubview(colorWell)
        NSLayoutConstraint.activate([
            colorWell.widthAnchor.constraint(equalToConstant: 28),
            colorWell.heightAnchor.constraint(equalToConstant: 28),
        ])

        // Color presets
        let presetColors: [(NSColor, String)] = [
            (.systemRed, "Red annotation color"),
            (.systemYellow, "Yellow annotation color"),
            (.systemGreen, "Green annotation color"),
            (.systemBlue, "Blue annotation color"),
        ]
        for (color, label) in presetColors {
            let swatch = makeColorSwatch(color: color, label: label)
            stack.addArrangedSubview(swatch)
        }

        let secondDivider = NSBox()
        secondDivider.boxType = .separator
        secondDivider.translatesAutoresizingMaskIntoConstraints = false
        stack.addArrangedSubview(secondDivider)
        NSLayoutConstraint.activate([
            secondDivider.widthAnchor.constraint(equalToConstant: 44),
        ])

        configureOptionPopup(
            lineWidthPopup,
            titles: ["1 px", "2 px", "3 px", "4 px", "5 px"],
            selectedTitle: "\(Int(selectedLineWidth)) px",
            tooltip: "Stroke Width",
            action: #selector(lineWidthChanged)
        )
        stack.addArrangedSubview(lineWidthPopup)

        configureOptionPopup(
            fontSizePopup,
            titles: ["8 pt", "12 pt", "16 pt", "20 pt", "24 pt", "32 pt", "48 pt", "64 pt", "72 pt"],
            selectedTitle: "\(Int(selectedFontSize)) pt",
            tooltip: "Text Size",
            action: #selector(fontSizeChanged)
        )
        stack.addArrangedSubview(fontSizePopup)

        visualEffect.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: visualEffect.topAnchor, constant: 8),
            stack.centerXAnchor.constraint(equalTo: visualEffect.centerXAnchor),
        ])
    }

    private func makeToolButton(tool: AnnotationType) -> NSButton {
        let button = NSButton()
        button.bezelStyle = .recessed
        button.setButtonType(.pushOnPushOff)
        button.isBordered = true
        button.image = NSImage(systemSymbolName: tool.toolbarSymbol, accessibilityDescription: tool.tooltip)
        button.toolTip = tool.tooltip
        button.target = self
        button.action = #selector(toolTapped(_:))
        button.tag = AnnotationType.allCases.firstIndex(of: tool) ?? 0
        button.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: 32),
            button.heightAnchor.constraint(equalToConstant: 32),
        ])
        return button
    }

    private func makeColorSwatch(color: NSColor, label: String) -> NSView {
        let button = NSButton()
        button.bezelStyle = .recessed
        button.isBordered = false
        button.wantsLayer = true
        button.layer?.backgroundColor = color.cgColor
        button.layer?.cornerRadius = 4
        button.target = self
        button.action = #selector(swatchTapped(_:))
        button.toolTip = label
        button.setAccessibilityLabel(label)
        button.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: 20),
            button.heightAnchor.constraint(equalToConstant: 20),
        ])
        // Store color reference via tag — use hash of color
        swatchColorMap[ObjectIdentifier(button)] = color
        return button
    }

    private func configureHistoryButton(
        _ button: NSButton,
        symbol: String,
        label: String,
        action: Selector
    ) {
        button.bezelStyle = .recessed
        button.isBordered = true
        button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: label)
        button.imagePosition = .imageOnly
        button.toolTip = label
        button.target = self
        button.action = action
        button.isEnabled = false
        button.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: 28),
            button.heightAnchor.constraint(equalToConstant: 28),
        ])
    }

    func setHistoryAvailability(canUndo: Bool, canRedo: Bool) {
        undoButton.isEnabled = canUndo
        redoButton.isEnabled = canRedo
    }

    private func configureOptionPopup(
        _ popup: NSPopUpButton,
        titles: [String],
        selectedTitle: String,
        tooltip: String,
        action: Selector
    ) {
        popup.addItems(withTitles: titles)
        popup.selectItem(withTitle: selectedTitle)
        popup.toolTip = tooltip
        popup.setAccessibilityLabel(tooltip)
        popup.target = self
        popup.action = action
        popup.controlSize = .small
        popup.font = NSFont.systemFont(ofSize: 10)
        popup.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            popup.widthAnchor.constraint(equalToConstant: 58),
            popup.heightAnchor.constraint(equalToConstant: 24),
        ])
    }

    private var swatchColorMap: [ObjectIdentifier: NSColor] = [:]

    @objc private func toolTapped(_ sender: NSButton) {
        let tool = AnnotationType.allCases[sender.tag]
        if selectedTool == tool {
            selectedTool = nil
        } else {
            selectedTool = tool
        }
        onToolChanged?(selectedTool)
    }

    @objc private func selectionTapped() {
        selectedTool = nil
        onToolChanged?(nil)
    }

    @objc private func swatchTapped(_ sender: NSButton) {
        if let color = swatchColorMap[ObjectIdentifier(sender)] {
            selectedColor = color
            colorWell.color = color
            onColorChanged?(color)
        }
    }

    @objc private func colorChanged() {
        selectedColor = colorWell.color
        onColorChanged?(selectedColor)
    }

    @objc private func lineWidthChanged() {
        let value = lineWidthPopup.titleOfSelectedItem?
            .split(separator: " ")
            .first
            .flatMap { Double($0) } ?? Double(selectedLineWidth)
        selectedLineWidth = CGFloat(value)
        onLineWidthChanged?(selectedLineWidth)
    }

    @objc private func fontSizeChanged() {
        let value = fontSizePopup.titleOfSelectedItem?
            .split(separator: " ")
            .first
            .flatMap { Double($0) } ?? Double(selectedFontSize)
        selectedFontSize = CGFloat(value)
        onFontSizeChanged?(selectedFontSize)
    }

    @objc private func undoTapped() { onUndo?() }
    @objc private func redoTapped() { onRedo?() }

    private func updateSelection() {
        selectionButton.state = selectedTool == nil ? .on : .off
        for (tool, button) in toolButtons {
            button.state = (tool == selectedTool) ? .on : .off
        }
    }
}
