import AppKit

enum AnnotationTool: String, CaseIterable {
    case line
    case rectangle
}

final class EditingToolbar: NSView {
    var selectedTool: AnnotationTool? {
        didSet { updateSelection() }
    }
    var selectedColor: NSColor = .systemRed {
        didSet { colorWell.color = selectedColor }
    }
    var onToolChanged: ((AnnotationTool?) -> Void)?
    var onColorChanged: ((NSColor) -> Void)?

    static let width: CGFloat = 44

    private var toolButtons: [AnnotationTool: NSButton] = [:]
    private let colorWell = NSColorWell()

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

        let rectButton = makeToolButton(
            tool: .rectangle,
            symbol: "rectangle",
            tooltip: "Rectangle"
        )
        toolButtons[.rectangle] = rectButton
        stack.addArrangedSubview(rectButton)

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

    private func updateSelection() {
        for (tool, button) in toolButtons {
            button.state = (tool == selectedTool) ? .on : .off
        }
    }
}
