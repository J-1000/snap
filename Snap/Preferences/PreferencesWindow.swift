import AppKit

final class PreferencesWindow: NSWindowController {
    private let prefs = PreferencesManager.shared

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 450, height: 340),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Snap Preferences"
        window.center()
        window.isReleasedWhenClosed = false
        self.init(window: window)
        setupUI()
    }

    private var formatPopup: NSPopUpButton!
    private var qualitySlider: NSSlider!
    private var qualityLabel: NSTextField!
    private var directoryLabel: NSTextField!
    private var retinaCheckbox: NSButton!
    private var clipboardCheckbox: NSButton!
    private var autoSaveCheckbox: NSButton!
    private var launchAtLoginCheckbox: NSButton!

    private func setupUI() {
        guard let contentView = window?.contentView else { return }

        let padding: CGFloat = 20
        var y: CGFloat = 300

        // Save directory
        y -= 30
        let dirTitleLabel = makeLabel("Save Directory:", bold: true)
        dirTitleLabel.frame.origin = NSPoint(x: padding, y: y)
        contentView.addSubview(dirTitleLabel)

        y -= 26
        directoryLabel = makeLabel(prefs.saveDirectory.path)
        directoryLabel.frame = NSRect(x: padding, y: y, width: 300, height: 20)
        directoryLabel.lineBreakMode = .byTruncatingMiddle
        contentView.addSubview(directoryLabel)

        let chooseButton = NSButton(title: "Choose…", target: self, action: #selector(chooseSaveDirectory))
        chooseButton.frame = NSRect(x: 330, y: y - 2, width: 100, height: 24)
        chooseButton.bezelStyle = .rounded
        contentView.addSubview(chooseButton)

        // Image format
        y -= 40
        let formatLabel = makeLabel("Image Format:", bold: true)
        formatLabel.frame.origin = NSPoint(x: padding, y: y)
        contentView.addSubview(formatLabel)

        formatPopup = NSPopUpButton(frame: NSRect(x: 150, y: y - 2, width: 100, height: 24))
        formatPopup.addItems(withTitles: ["PNG", "JPEG"])
        formatPopup.selectItem(withTitle: prefs.imageFormat.uppercased())
        formatPopup.target = self
        formatPopup.action = #selector(formatChanged)
        contentView.addSubview(formatPopup)

        // JPEG quality
        y -= 34
        let qualityTitleLabel = makeLabel("JPEG Quality:")
        qualityTitleLabel.frame.origin = NSPoint(x: padding + 20, y: y)
        contentView.addSubview(qualityTitleLabel)

        qualitySlider = NSSlider(value: prefs.jpegQuality, minValue: 0.1, maxValue: 1.0, target: self, action: #selector(qualityChanged))
        qualitySlider.frame = NSRect(x: 150, y: y, width: 200, height: 20)
        qualitySlider.isEnabled = prefs.imageFormat == "jpeg"
        contentView.addSubview(qualitySlider)

        qualityLabel = makeLabel("\(Int(prefs.jpegQuality * 100))%")
        qualityLabel.frame = NSRect(x: 360, y: y, width: 50, height: 20)
        contentView.addSubview(qualityLabel)

        // Checkboxes
        y -= 40
        retinaCheckbox = NSButton(checkboxWithTitle: "Downscale Retina screenshots to 1x", target: self, action: #selector(retinaToggled))
        retinaCheckbox.frame.origin = NSPoint(x: padding, y: y)
        retinaCheckbox.state = prefs.downscaleRetina ? .on : .off
        contentView.addSubview(retinaCheckbox)

        y -= 26
        clipboardCheckbox = NSButton(checkboxWithTitle: "Copy to clipboard after capture", target: self, action: #selector(clipboardToggled))
        clipboardCheckbox.frame.origin = NSPoint(x: padding, y: y)
        clipboardCheckbox.state = prefs.copyToClipboardAfterCapture ? .on : .off
        contentView.addSubview(clipboardCheckbox)

        y -= 26
        autoSaveCheckbox = NSButton(checkboxWithTitle: "Auto-save after capture", target: self, action: #selector(autoSaveToggled))
        autoSaveCheckbox.frame.origin = NSPoint(x: padding, y: y)
        autoSaveCheckbox.state = prefs.autoSaveAfterCapture ? .on : .off
        contentView.addSubview(autoSaveCheckbox)

        y -= 34
        let separator = NSBox()
        separator.boxType = .separator
        separator.frame = NSRect(x: padding, y: y, width: 410, height: 1)
        contentView.addSubview(separator)

        y -= 30
        launchAtLoginCheckbox = NSButton(checkboxWithTitle: "Launch Snap at login", target: self, action: #selector(launchAtLoginToggled))
        launchAtLoginCheckbox.frame.origin = NSPoint(x: padding, y: y)
        launchAtLoginCheckbox.state = prefs.launchAtLogin ? .on : .off
        contentView.addSubview(launchAtLoginCheckbox)
    }

    private func makeLabel(_ text: String, bold: Bool = false) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = bold ? NSFont.boldSystemFont(ofSize: 13) : NSFont.systemFont(ofSize: 13)
        label.sizeToFit()
        return label
    }

    @objc private func chooseSaveDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.directoryURL = prefs.saveDirectory

        panel.begin { [weak self] response in
            guard let self = self, response == .OK, let url = panel.url else { return }
            self.prefs.saveDirectory = url
            self.directoryLabel.stringValue = url.path
        }
    }

    @objc private func formatChanged() {
        let format = formatPopup.titleOfSelectedItem?.lowercased() ?? "png"
        prefs.imageFormat = format
        qualitySlider.isEnabled = format == "jpeg"
    }

    @objc private func qualityChanged() {
        prefs.jpegQuality = qualitySlider.doubleValue
        qualityLabel.stringValue = "\(Int(qualitySlider.doubleValue * 100))%"
    }

    @objc private func retinaToggled() {
        prefs.downscaleRetina = retinaCheckbox.state == .on
    }

    @objc private func clipboardToggled() {
        prefs.copyToClipboardAfterCapture = clipboardCheckbox.state == .on
    }

    @objc private func autoSaveToggled() {
        prefs.autoSaveAfterCapture = autoSaveCheckbox.state == .on
    }

    @objc private func launchAtLoginToggled() {
        prefs.launchAtLogin = launchAtLoginCheckbox.state == .on
    }
}
