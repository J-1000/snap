import AppKit

final class PreferencesWindow: NSWindowController {
    private let prefs = PreferencesManager.shared

    private var formatPopup: NSPopUpButton!
    private var qualitySlider: NSSlider!
    private var qualityLabel: NSTextField!
    private var directoryLabel: NSTextField!
    private var retinaCheckbox: NSButton!
    private var clipboardCheckbox: NSButton!
    private var autoSaveCheckbox: NSButton!
    private var openEditorCheckbox: NSButton!
    private var cursorCheckbox: NSButton!
    private var notificationCheckbox: NSButton!
    private var launchAtLoginCheckbox: NSButton!
    private var hdrCheckbox: NSButton?
    private var areaShortcutRecorder: ShortcutRecorder!
    private var fullScreenShortcutRecorder: ShortcutRecorder!
    private var shortcutErrorLabel: NSTextField!
    private var historyCheckbox: NSButton!
    private var clearHistoryButton: NSButton!

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 650),
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

    private func setupUI() {
        guard let contentView = window?.contentView else { return }

        let rootStack = NSStackView()
        rootStack.orientation = .vertical
        rootStack.alignment = .leading
        rootStack.spacing = 18
        rootStack.edgeInsets = NSEdgeInsets(top: 22, left: 24, bottom: 22, right: 24)
        rootStack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(rootStack)

        NSLayoutConstraint.activate([
            rootStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            rootStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            rootStack.topAnchor.constraint(equalTo: contentView.topAnchor),
            rootStack.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor),
        ])

        rootStack.addArrangedSubview(makeCaptureSection())
        rootStack.addArrangedSubview(makeOutputSection())
        rootStack.addArrangedSubview(makeEditorSection())
        rootStack.addArrangedSubview(makeSystemSection())
    }

    private func makeCaptureSection() -> NSView {
        let stack = makeSection(title: "Capture")
        areaShortcutRecorder = ShortcutRecorder(shortcut: prefs.areaCaptureShortcut)
        areaShortcutRecorder.setAccessibilityIdentifier("area-capture-shortcut")
        areaShortcutRecorder.onShortcutRecorded = { [weak self] shortcut in
            self?.saveShortcut(shortcut, forAreaCapture: true)
        }
        stack.addArrangedSubview(
            makeControlRow(label: "Area capture", controls: [areaShortcutRecorder])
        )

        fullScreenShortcutRecorder = ShortcutRecorder(shortcut: prefs.fullScreenCaptureShortcut)
        fullScreenShortcutRecorder.setAccessibilityIdentifier("full-screen-capture-shortcut")
        fullScreenShortcutRecorder.onShortcutRecorded = { [weak self] shortcut in
            self?.saveShortcut(shortcut, forAreaCapture: false)
        }
        stack.addArrangedSubview(
            makeControlRow(label: "Full screen", controls: [fullScreenShortcutRecorder])
        )

        shortcutErrorLabel = NSTextField(wrappingLabelWithString: "")
        shortcutErrorLabel.textColor = .systemRed
        shortcutErrorLabel.font = .systemFont(ofSize: 11)
        shortcutErrorLabel.maximumNumberOfLines = 2
        shortcutErrorLabel.isHidden = true
        shortcutErrorLabel.setAccessibilityLabel("Shortcut conflict")
        shortcutErrorLabel.widthAnchor.constraint(equalToConstant: 430).isActive = true
        stack.addArrangedSubview(shortcutErrorLabel)

        cursorCheckbox = makeCheckbox(
            title: "Include mouse cursor",
            state: prefs.includeMouseCursor,
            action: #selector(cursorToggled)
        )
        stack.addArrangedSubview(cursorCheckbox)
        if #available(macOS 26.0, *) {
            let checkbox = makeCheckbox(
                title: "Capture HDR on supported displays",
                state: prefs.captureHDR,
                action: #selector(hdrToggled)
            )
            hdrCheckbox = checkbox
            stack.addArrangedSubview(checkbox)
        }
        return stack
    }

    private func makeOutputSection() -> NSView {
        let stack = makeSection(title: "Output")

        directoryLabel = NSTextField(labelWithString: prefs.saveDirectory.path)
        directoryLabel.lineBreakMode = .byTruncatingMiddle
        directoryLabel.maximumNumberOfLines = 1

        let chooseButton = NSButton(title: "Choose...", target: self, action: #selector(chooseSaveDirectory))
        chooseButton.bezelStyle = .rounded
        stack.addArrangedSubview(makeControlRow(label: "Save directory", controls: [directoryLabel, chooseButton]))
        directoryLabel.widthAnchor.constraint(equalToConstant: 280).isActive = true

        formatPopup = NSPopUpButton()
        var formats = ["PNG", "JPEG"]
        if #available(macOS 26.0, *) {
            formats.append("HEIC")
        }
        formatPopup.addItems(withTitles: formats)
        formatPopup.selectItem(withTitle: prefs.imageFormat.uppercased())
        formatPopup.target = self
        formatPopup.action = #selector(formatChanged)
        stack.addArrangedSubview(makeControlRow(label: "Image format", controls: [formatPopup]))

        qualitySlider = NSSlider(value: prefs.jpegQuality, minValue: 0.1, maxValue: 1.0, target: self, action: #selector(qualityChanged))
        qualitySlider.widthAnchor.constraint(equalToConstant: 220).isActive = true
        qualitySlider.isEnabled = prefs.imageFormat == "jpeg"
        qualityLabel = NSTextField(labelWithString: "\(Int(prefs.jpegQuality * 100))%")
        qualityLabel.widthAnchor.constraint(equalToConstant: 44).isActive = true
        stack.addArrangedSubview(makeControlRow(label: "JPEG quality", controls: [qualitySlider, qualityLabel]))

        retinaCheckbox = makeCheckbox(
            title: "Downscale Retina screenshots to 1x",
            state: prefs.downscaleRetina,
            action: #selector(retinaToggled)
        )
        stack.addArrangedSubview(retinaCheckbox)

        clipboardCheckbox = makeCheckbox(
            title: "Copy to clipboard after capture",
            state: prefs.copyToClipboardAfterCapture,
            action: #selector(clipboardToggled)
        )
        stack.addArrangedSubview(clipboardCheckbox)

        autoSaveCheckbox = makeCheckbox(
            title: "Auto-save after capture",
            state: prefs.autoSaveAfterCapture,
            action: #selector(autoSaveToggled)
        )
        stack.addArrangedSubview(autoSaveCheckbox)

        historyCheckbox = makeCheckbox(
            title: "Keep up to 20 recent captures in local history",
            state: prefs.captureHistoryEnabled,
            action: #selector(historyToggled)
        )
        historyCheckbox.toolTip = "Off by default. History is stored only on this Mac."
        stack.addArrangedSubview(historyCheckbox)

        clearHistoryButton = NSButton(title: "Clear Capture History…", target: self, action: #selector(clearHistoryTapped))
        clearHistoryButton.bezelStyle = .rounded
        clearHistoryButton.isEnabled = !CaptureHistoryStore.shared.entries.isEmpty
        stack.addArrangedSubview(clearHistoryButton)
        return stack
    }

    private func makeEditorSection() -> NSView {
        let stack = makeSection(title: "Editor")
        openEditorCheckbox = makeCheckbox(
            title: "Open editor after automatic copy or save",
            state: prefs.openEditorAfterCapture,
            action: #selector(openEditorToggled)
        )
        stack.addArrangedSubview(openEditorCheckbox)
        return stack
    }

    private func makeSystemSection() -> NSView {
        let stack = makeSection(title: "System")

        notificationCheckbox = makeCheckbox(
            title: "Show save and copy notifications",
            state: prefs.showNotifications,
            action: #selector(notificationToggled)
        )
        stack.addArrangedSubview(notificationCheckbox)

        launchAtLoginCheckbox = makeCheckbox(
            title: "Launch Snap at login",
            state: prefs.launchAtLogin,
            action: #selector(launchAtLoginToggled)
        )
        stack.addArrangedSubview(launchAtLoginCheckbox)
        return stack
    }

    private func makeSection(title: String) -> NSStackView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false

        let label = NSTextField(labelWithString: title)
        label.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        stack.addArrangedSubview(label)
        return stack
    }

    private func makeInfoRow(label: String, value: String) -> NSView {
        let valueLabel = NSTextField(labelWithString: value)
        valueLabel.textColor = .secondaryLabelColor
        return makeControlRow(label: label, controls: [valueLabel])
    }

    private func saveShortcut(_ shortcut: HotKeyManager.HotKey, forAreaCapture: Bool) {
        let other = forAreaCapture ? prefs.fullScreenCaptureShortcut : prefs.areaCaptureShortcut
        if let error = HotKeyManager.validationError(for: shortcut, conflictingWith: other) {
            shortcutErrorLabel.stringValue = error
            shortcutErrorLabel.isHidden = false
            NSSound.beep()
            if forAreaCapture {
                areaShortcutRecorder.shortcut = prefs.areaCaptureShortcut
            } else {
                fullScreenShortcutRecorder.shortcut = prefs.fullScreenCaptureShortcut
            }
            return
        }

        shortcutErrorLabel.isHidden = true
        if forAreaCapture {
            prefs.areaCaptureShortcut = shortcut
            areaShortcutRecorder.shortcut = shortcut
        } else {
            prefs.fullScreenCaptureShortcut = shortcut
            fullScreenShortcutRecorder.shortcut = shortcut
        }
    }

    private func makeControlRow(label: String, controls: [NSView]) -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 10
        row.translatesAutoresizingMaskIntoConstraints = false

        let labelView = NSTextField(labelWithString: label)
        labelView.textColor = .secondaryLabelColor
        labelView.alignment = .right
        labelView.widthAnchor.constraint(equalToConstant: 110).isActive = true
        row.addArrangedSubview(labelView)

        for control in controls {
            row.addArrangedSubview(control)
        }
        return row
    }

    private func makeCheckbox(title: String, state: Bool, action: Selector) -> NSButton {
        let checkbox = NSButton(checkboxWithTitle: title, target: self, action: action)
        checkbox.state = state ? .on : .off
        return checkbox
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

    @objc private func historyToggled() {
        let enabled = historyCheckbox.state == .on
        prefs.captureHistoryEnabled = enabled
        if !enabled {
            CaptureHistoryStore.shared.clear()
        }
        clearHistoryButton.isEnabled = enabled && !CaptureHistoryStore.shared.entries.isEmpty
    }

    @objc private func clearHistoryTapped() {
        let alert = NSAlert()
        alert.messageText = "Clear capture history?"
        alert.informativeText = "This permanently deletes all screenshots stored by Snap history."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Clear History")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        CaptureHistoryStore.shared.clear()
        clearHistoryButton.isEnabled = false
    }

    @objc private func openEditorToggled() {
        prefs.openEditorAfterCapture = openEditorCheckbox.state == .on
    }

    @objc private func cursorToggled() {
        prefs.includeMouseCursor = cursorCheckbox.state == .on
    }

    @objc private func hdrToggled() {
        prefs.captureHDR = hdrCheckbox?.state == .on
    }

    @objc private func notificationToggled() {
        prefs.showNotifications = notificationCheckbox.state == .on
    }

    @objc private func launchAtLoginToggled() {
        prefs.launchAtLogin = launchAtLoginCheckbox.state == .on
    }
}

/// Keyboard-first shortcut recorder used by Preferences. Clicking it focuses
/// the control; the next key-down plus modifiers becomes the candidate binding.
private final class ShortcutRecorder: NSButton {
    var shortcut: HotKeyManager.HotKey {
        didSet { updateTitle() }
    }
    var onShortcutRecorded: ((HotKeyManager.HotKey) -> Void)?

    init(shortcut: HotKeyManager.HotKey) {
        self.shortcut = shortcut
        super.init(frame: .zero)
        bezelStyle = .rounded
        setButtonType(.momentaryPushIn)
        toolTip = "Click, then press a new keyboard shortcut"
        setAccessibilityLabel("Keyboard shortcut")
        widthAnchor.constraint(equalToConstant: 150).isActive = true
        updateTitle()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override var acceptsFirstResponder: Bool { true }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        title = "Press shortcut…"
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            window?.makeFirstResponder(nil)
            return
        }

        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        var modifiers: CGEventFlags = []
        if flags.contains(.command) { modifiers.insert(.maskCommand) }
        if flags.contains(.shift) { modifiers.insert(.maskShift) }
        if flags.contains(.option) { modifiers.insert(.maskAlternate) }
        if flags.contains(.control) { modifiers.insert(.maskControl) }

        onShortcutRecorded?(
            HotKeyManager.HotKey(
                keyCode: CGKeyCode(event.keyCode),
                modifiers: modifiers
            )
        )
        window?.makeFirstResponder(nil)
    }

    override func resignFirstResponder() -> Bool {
        updateTitle()
        return super.resignFirstResponder()
    }

    private func updateTitle() {
        title = shortcut.displayString
        setAccessibilityValue("Current shortcut: \(shortcut.displayString)")
    }
}
