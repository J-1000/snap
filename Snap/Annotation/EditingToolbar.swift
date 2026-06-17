import AppKit

enum AnnotationTool: String, CaseIterable {
    case line
    case arrow
    case freehand
    case rectangle
    case ellipse
    case text
    case blur
}

final class EditingToolbar: NSView {
    var selectedTool: AnnotationTool? {
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
    var onToolChanged: ((AnnotationTool?) -> Void)?
    var onColorChanged: ((NSColor) -> Void)?
    var onLineWidthChanged: ((CGFloat) -> Void)?
    var onFontSizeChanged: ((CGFloat) -> Void)?

    static let width: CGFloat = 72

    private var toolButtons: [AnnotationTool: NSButton] = [:]
    private let colorWell = NSColorWell()
    private let lineWidthPopup = NSPopUpButton()
    private let fontSizePopup = NSPopUpButton()

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

        // Tool buttons
        let lineButton = makeToolButton(
            tool: .line,
            symbol: "line.diagonal",
            tooltip: "Line"
        )
        toolButtons[.line] = lineButton
        stack.addArrangedSubview(lineButton)

        let arrowButton = makeToolButton(
            tool: .arrow,
            symbol: "arrow.up.right",
            tooltip: "Arrow"
        )
        toolButtons[.arrow] = arrowButton
        stack.addArrangedSubview(arrowButton)

        let freehandButton = makeToolButton(
            tool: .freehand,
            symbol: "scribble",
            tooltip: "Freehand"
        )
        toolButtons[.freehand] = freehandButton
        stack.addArrangedSubview(freehandButton)

        let rectButton = makeToolButton(
            tool: .rectangle,
            symbol: "rectangle",
            tooltip: "Rectangle"
        )
        toolButtons[.rectangle] = rectButton
        stack.addArrangedSubview(rectButton)

        let ellipseButton = makeToolButton(
            tool: .ellipse,
            symbol: "oval",
            tooltip: "Ellipse"
        )
        toolButtons[.ellipse] = ellipseButton
        stack.addArrangedSubview(ellipseButton)

        let textButton = makeToolButton(
            tool: .text,
            symbol: "textformat",
            tooltip: "Text"
        )
        toolButtons[.text] = textButton
        stack.addArrangedSubview(textButton)

        let blurButton = makeToolButton(
            tool: .blur,
            symbol: "square.grid.3x3",
            tooltip: "Blur / Pixelate"
        )
        toolButtons[.blur] = blurButton
        stack.addArrangedSubview(blurButton)

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
        if #available(macOS 13.0, *) {
            colorWell.colorWellStyle = .minimal
        }
        stack.addArrangedSubview(colorWell)
        NSLayoutConstraint.activate([
            colorWell.widthAnchor.constraint(equalToConstant: 28),
            colorWell.heightAnchor.constraint(equalToConstant: 28),
        ])

        // Color presets
        let presetColors: [NSColor] = [.systemRed, .systemYellow, .systemGreen, .systemBlue]
        for color in presetColors {
            let swatch = makeColorSwatch(color: color)
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
            titles: ["12 pt", "16 pt", "20 pt", "24 pt", "32 pt", "48 pt"],
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

    private func makeToolButton(tool: AnnotationTool, symbol: String, tooltip: String) -> NSButton {
        let button = NSButton()
        button.bezelStyle = .recessed
        button.setButtonType(.pushOnPushOff)
        button.isBordered = true
        button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: tooltip)
        button.toolTip = tooltip
        button.target = self
        button.action = #selector(toolTapped(_:))
        button.tag = AnnotationTool.allCases.firstIndex(of: tool)!
        button.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: 32),
            button.heightAnchor.constraint(equalToConstant: 32),
        ])
        return button
    }

    private func makeColorSwatch(color: NSColor) -> NSView {
        let button = NSButton()
        button.bezelStyle = .recessed
        button.isBordered = false
        button.wantsLayer = true
        button.layer?.backgroundColor = color.cgColor
        button.layer?.cornerRadius = 4
        button.target = self
        button.action = #selector(swatchTapped(_:))
        button.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: 20),
            button.heightAnchor.constraint(equalToConstant: 20),
        ])
        // Store color reference via tag — use hash of color
        swatchColorMap[ObjectIdentifier(button)] = color
        return button
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
        let tool = AnnotationTool.allCases[sender.tag]
        if selectedTool == tool {
            selectedTool = nil
        } else {
            selectedTool = tool
        }
        onToolChanged?(selectedTool)
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

    private func updateSelection() {
        for (tool, button) in toolButtons {
            button.state = (tool == selectedTool) ? .on : .off
        }
    }
}
