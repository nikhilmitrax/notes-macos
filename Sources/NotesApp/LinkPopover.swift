import AppKit

class LinkPopoverController {
    private let popover = NSPopover()
    private var viewController: LinkPopoverViewController?
    private var dismissWork: DispatchWorkItem?

    var isShown: Bool { popover.isShown }

    func show(relativeTo rect: NSRect, of view: NSView, urlString: String, title: String,
              range: NSRange, onUpdate: @escaping (String, String, NSRange) -> Void) {
        let vc = LinkPopoverViewController(
            urlString: urlString, title: title, range: range, onUpdate: onUpdate,
            onMouseInside: { [weak self] inside in
                if inside {
                    self?.cancelDismiss()
                } else {
                    self?.scheduleDismiss()
                }
            }
        )
        viewController = vc

        popover.contentViewController = vc
        popover.behavior = .semitransient
        popover.contentSize = NSSize(width: 320, height: 72)
        popover.show(relativeTo: rect, of: view, preferredEdge: .maxY)
    }

    func update(urlString: String, title: String, range: NSRange) {
        viewController?.updateURL(urlString)
        viewController?.updateTitle(title)
        viewController?.range = range
    }

    func scheduleDismiss() {
        dismissWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.dismiss()
        }
        dismissWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: work)
    }

    func cancelDismiss() {
        dismissWork?.cancel()
        dismissWork = nil
    }

    func dismiss() {
        dismissWork?.cancel()
        dismissWork = nil
        if popover.isShown {
            popover.performClose(nil)
        }
    }
}

class LinkPopoverViewController: NSViewController {
    private var urlString: String
    private var linkTitle: String
    var range: NSRange
    private let onUpdate: (String, String, NSRange) -> Void
    private let onMouseInside: (Bool) -> Void
    private var urlField: NSTextField!
    private var titleField: NSTextField!

    init(urlString: String, title: String, range: NSRange,
         onUpdate: @escaping (String, String, NSRange) -> Void,
         onMouseInside: @escaping (Bool) -> Void) {
        self.urlString = urlString
        self.linkTitle = title
        self.range = range
        self.onUpdate = onUpdate
        self.onMouseInside = onMouseInside
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        let container = TrackingView(frame: NSRect(x: 0, y: 0, width: 320, height: 72))
        container.onMouseInside = onMouseInside

        let titleLabel = NSTextField(labelWithString: "Title")
        titleLabel.frame = NSRect(x: 8, y: 44, width: 36, height: 18)
        titleLabel.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        titleLabel.textColor = .secondaryLabelColor
        container.addSubview(titleLabel)

        titleField = NSTextField(string: linkTitle)
        titleField.frame = NSRect(x: 44, y: 40, width: 268, height: 24)
        titleField.font = NSFont.systemFont(ofSize: 12)
        titleField.bezelStyle = .roundedBezel
        titleField.target = self
        titleField.action = #selector(fieldsChanged)
        container.addSubview(titleField)

        let urlLabel = NSTextField(labelWithString: "URL")
        urlLabel.frame = NSRect(x: 8, y: 12, width: 36, height: 18)
        urlLabel.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        urlLabel.textColor = .secondaryLabelColor
        container.addSubview(urlLabel)

        urlField = NSTextField(string: urlString)
        urlField.frame = NSRect(x: 44, y: 8, width: 208, height: 24)
        urlField.font = NSFont.systemFont(ofSize: 12)
        urlField.bezelStyle = .roundedBezel
        urlField.target = self
        urlField.action = #selector(fieldsChanged)
        container.addSubview(urlField)

        let openButton = NSButton(title: "Open", target: self, action: #selector(openURL))
        openButton.frame = NSRect(x: 256, y: 6, width: 56, height: 28)
        openButton.bezelStyle = .rounded
        openButton.font = NSFont.systemFont(ofSize: 12)
        container.addSubview(openButton)

        self.view = container
    }

    func updateURL(_ urlString: String) {
        self.urlString = urlString
        urlField?.stringValue = urlString
    }

    func updateTitle(_ title: String) {
        self.linkTitle = title
        titleField?.stringValue = title
    }

    @objc private func fieldsChanged() {
        onUpdate(urlField.stringValue, titleField.stringValue, range)
    }

    @objc private func openURL() {
        if let url = URL(string: urlField.stringValue) {
            NSWorkspace.shared.open(url)
        }
    }
}

/// A view that reports mouse enter/exit to a callback.
private class TrackingView: NSView {
    var onMouseInside: ((Bool) -> Void)?

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        for area in trackingAreas {
            removeTrackingArea(area)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeInKeyWindow],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
    }

    override func mouseEntered(with event: NSEvent) {
        onMouseInside?(true)
    }

    override func mouseExited(with event: NSEvent) {
        onMouseInside?(false)
    }
}
