import AppKit

@MainActor
final class CaptureHistoryWindowController: NSWindowController {
    private let store: CaptureHistoryStore
    private let entriesStack = NSStackView()
    private let clearButton = NSButton()

    init(store: CaptureHistoryStore = .shared) {
        self.store = store
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 680, height: 520),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Capture History"
        window.minSize = NSSize(width: 560, height: 360)
        window.center()
        window.isReleasedWhenClosed = false
        super.init(window: window)
        setupUI()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func showWindow(_ sender: Any?) {
        reload()
        super.showWindow(sender)
    }

    private func setupUI() {
        guard let content = window?.contentView else { return }

        let header = NSStackView()
        header.orientation = .horizontal
        header.alignment = .centerY
        header.translatesAutoresizingMaskIntoConstraints = false
        let title = NSTextField(labelWithString: "Recent captures stored locally on this Mac")
        title.font = .systemFont(ofSize: 13, weight: .semibold)
        header.addArrangedSubview(title)
        header.addArrangedSubview(NSView())
        clearButton.title = "Clear All"
        clearButton.bezelStyle = .rounded
        clearButton.target = self
        clearButton.action = #selector(clearAllTapped)
        clearButton.setAccessibilityLabel("Clear all capture history")
        header.addArrangedSubview(clearButton)
        content.addSubview(header)

        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(scrollView)

        let document = NSView()
        document.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = document

        entriesStack.orientation = .vertical
        entriesStack.alignment = .leading
        entriesStack.spacing = 10
        entriesStack.translatesAutoresizingMaskIntoConstraints = false
        document.addSubview(entriesStack)

        NSLayoutConstraint.activate([
            header.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 16),
            header.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -16),
            header.topAnchor.constraint(equalTo: content.topAnchor, constant: 14),
            scrollView.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 10),
            scrollView.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            document.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor),
            entriesStack.leadingAnchor.constraint(equalTo: document.leadingAnchor, constant: 16),
            entriesStack.trailingAnchor.constraint(equalTo: document.trailingAnchor, constant: -16),
            entriesStack.topAnchor.constraint(equalTo: document.topAnchor, constant: 8),
            entriesStack.bottomAnchor.constraint(equalTo: document.bottomAnchor, constant: -16),
        ])
        reload()
    }

    private func reload() {
        for view in entriesStack.arrangedSubviews {
            entriesStack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        guard PreferencesManager.shared.captureHistoryEnabled else {
            clearButton.isEnabled = false
            entriesStack.addArrangedSubview(messageLabel(
                "Capture history is off. Enable it in Preferences to keep up to 20 recent captures."
            ))
            return
        }

        clearButton.isEnabled = !store.entries.isEmpty
        guard !store.entries.isEmpty else {
            entriesStack.addArrangedSubview(messageLabel("No captures in history yet."))
            return
        }

        for entry in store.entries {
            entriesStack.addArrangedSubview(makeRow(for: entry))
        }
    }

    private func messageLabel(_ text: String) -> NSTextField {
        let label = NSTextField(wrappingLabelWithString: text)
        label.textColor = .secondaryLabelColor
        label.widthAnchor.constraint(equalToConstant: 600).isActive = true
        return label
    }

    private func makeRow(for entry: CaptureHistoryEntry) -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 12
        row.edgeInsets = NSEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        row.wantsLayer = true
        row.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        row.layer?.cornerRadius = 8
        row.widthAnchor.constraint(equalTo: entriesStack.widthAnchor).isActive = true

        let thumbnail = NSImageView()
        thumbnail.imageScaling = .scaleProportionallyUpOrDown
        thumbnail.imageAlignment = .alignCenter
        thumbnail.wantsLayer = true
        thumbnail.layer?.backgroundColor = NSColor.black.cgColor
        thumbnail.image = store.image(for: entry).map {
            NSImage(cgImage: $0, size: NSSize(width: entry.pixelWidth, height: entry.pixelHeight))
        }
        thumbnail.setAccessibilityLabel("Screenshot from \(Self.dateFormatter.string(from: entry.createdAt))")
        NSLayoutConstraint.activate([
            thumbnail.widthAnchor.constraint(equalToConstant: 100),
            thumbnail.heightAnchor.constraint(equalToConstant: 68),
        ])
        row.addArrangedSubview(thumbnail)

        let details = NSStackView()
        details.orientation = .vertical
        details.alignment = .leading
        details.spacing = 3
        let date = NSTextField(labelWithString: Self.dateFormatter.string(from: entry.createdAt))
        date.font = .systemFont(ofSize: 12, weight: .medium)
        details.addArrangedSubview(date)
        let dimensions = NSTextField(labelWithString: "\(entry.pixelWidth) × \(entry.pixelHeight) px")
        dimensions.textColor = .secondaryLabelColor
        details.addArrangedSubview(dimensions)
        row.addArrangedSubview(details)
        row.addArrangedSubview(NSView())

        row.addArrangedSubview(actionButton(title: "Copy") { [weak self] in
            guard let self, let image = self.store.image(for: entry) else { return }
            if OutputManager.copyToClipboard(image, scaleFactor: entry.scaleFactor) {
                OutputManager.showNotification(title: "Snap", text: "History capture copied")
            }
        })
        row.addArrangedSubview(actionButton(title: "Save As…") { [weak self] in
            guard let self, let image = self.store.image(for: entry) else { return }
            OutputManager.saveWithDialog(image)
        })
        row.addArrangedSubview(actionButton(title: "Pin") { [weak self] in
            guard let self, let image = self.store.image(for: entry),
                  let delegate = NSApp.delegate as? AppDelegate else { return }
            delegate.pinScreenshot(image, scaleFactor: entry.scaleFactor, screen: self.window?.screen)
        })
        row.addArrangedSubview(actionButton(title: "Delete") { [weak self] in
            self?.store.remove(entry)
            self?.reload()
        })
        return row
    }

    private func actionButton(title: String, handler: @escaping () -> Void) -> NSButton {
        let button = HistoryActionButton(title: title, handler: handler)
        button.bezelStyle = .recessed
        button.controlSize = .small
        button.setAccessibilityLabel(title)
        return button
    }

    @objc private func clearAllTapped() {
        guard let window else { return }
        let alert = NSAlert()
        alert.messageText = "Clear capture history?"
        alert.informativeText = "This permanently deletes all screenshots stored by Snap history."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Clear History")
        alert.addButton(withTitle: "Cancel")
        alert.beginSheetModal(for: window) { [weak self] response in
            guard response == .alertFirstButtonReturn else { return }
            MainActor.assumeIsolated {
                self?.store.clear()
                self?.reload()
            }
        }
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}

private final class HistoryActionButton: NSButton {
    private let handler: () -> Void

    init(title: String, handler: @escaping () -> Void) {
        self.handler = handler
        super.init(frame: .zero)
        self.title = title
        target = self
        action = #selector(invoke)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    @objc private func invoke() { handler() }
}
