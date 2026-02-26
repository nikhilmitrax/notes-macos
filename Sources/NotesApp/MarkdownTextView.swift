import AppKit

class MarkdownTextView: NSTextView {
    var onTextChange: (() -> Void)?
    var forceSave: (() -> Void)?
    private var linkTrackingArea: NSTrackingArea?
    private var linkPopoverController: LinkPopoverController?

    override init(frame frameRect: NSRect, textContainer container: NSTextContainer?) {
        super.init(frame: frameRect, textContainer: container)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        isRichText = true
        allowsUndo = true
        isAutomaticSpellingCorrectionEnabled = false
        isAutomaticQuoteSubstitutionEnabled = false
        isAutomaticDashSubstitutionEnabled = false
        isAutomaticTextReplacementEnabled = false
        smartInsertDeleteEnabled = false
        usesFontPanel = false
        usesRuler = false
        drawsBackground = false
        backgroundColor = .clear
        insertionPointColor = Theme.textColor
        textContainerInset = NSSize(width: Theme.textContainerInsetWidth,
                                    height: Theme.textContainerInsetHeight)
        typingAttributes = Theme.bodyAttributes
        setupLinkTracking()
    }

    // MARK: - Insertion Point

    override func drawInsertionPoint(in rect: NSRect, color: NSColor, turnedOn flag: Bool) {
        let font = (typingAttributes[.font] as? NSFont) ?? Theme.bodyFont
        // Size cursor to the font's actual character height, not the full line height
        let cursorHeight = ceil(font.ascender - font.descender)
        let yOffset = (rect.height - cursorHeight) / 2
        var r = rect
        r.origin.y += yOffset
        r.size.height = cursorHeight
        super.drawInsertionPoint(in: r, color: color, turnedOn: flag)
    }

    // Ensure the full original rect is invalidated so the old cursor is fully erased
    override func setNeedsDisplay(_ invalidRect: NSRect, avoidAdditionalLayout flag: Bool) {
        var r = invalidRect
        r.origin.y = 0
        r.size.height = bounds.height
        super.setNeedsDisplay(r, avoidAdditionalLayout: flag)
    }

    // MARK: - Typing Attributes Override

    override var typingAttributes: [NSAttributedString.Key : Any] {
        get {
            var attrs = super.typingAttributes
            if attrs[.link] != nil {
                attrs.removeValue(forKey: .link)
                attrs.removeValue(forKey: .underlineStyle)
                if attrs[Theme.headingLevelKey] != nil {
                    attrs[.foregroundColor] = Theme.headingColor
                } else {
                    attrs[.foregroundColor] = Theme.textColor
                }
            }
            return attrs
        }
        set {
            super.typingAttributes = newValue
        }
    }

    // MARK: - Link Tracking

    private func setupLinkTracking() {
        let trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseMoved, .activeInKeyWindow, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
        linkTrackingArea = trackingArea
    }

    override func mouseMoved(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let charIndex = characterIndexForInsertion(at: point)

        guard let textStorage = textStorage,
              charIndex < textStorage.length,
              charIndex >= 0 else {
            scheduleDismissLinkPopover()
            super.mouseMoved(with: event)
            return
        }

        var effectiveRange = NSRange()
        if let link = textStorage.attribute(.link, at: charIndex, effectiveRange: &effectiveRange) {
            let urlString: String
            if let url = link as? URL {
                urlString = url.absoluteString
            } else if let str = link as? String {
                urlString = str
            } else {
                scheduleDismissLinkPopover()
                super.mouseMoved(with: event)
                return
            }
            let title = (textStorage.string as NSString).substring(with: effectiveRange)
            showLinkPopover(urlString: urlString, title: title, at: effectiveRange)
        } else {
            scheduleDismissLinkPopover()
        }

        super.mouseMoved(with: event)
    }

    private func showLinkPopover(urlString: String, title: String, at range: NSRange) {
        if linkPopoverController?.isShown == true {
            linkPopoverController?.cancelDismiss()
            linkPopoverController?.update(urlString: urlString, title: title, range: range)
            return
        }

        let glyphRange = layoutManager!.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
        let rect = layoutManager!.boundingRect(forGlyphRange: glyphRange, in: textContainer!)
        let adjustedRect = NSRect(
            x: rect.origin.x + textContainerInset.width,
            y: rect.origin.y + textContainerInset.height,
            width: rect.width,
            height: rect.height
        )

        let controller = LinkPopoverController()
        controller.show(
            relativeTo: adjustedRect,
            of: self,
            urlString: urlString,
            title: title,
            range: range,
            onUpdate: { [weak self] newURL, newTitle, range in
                self?.updateLink(newURL: newURL, newTitle: newTitle, range: range)
            }
        )
        linkPopoverController = controller
    }

    private func scheduleDismissLinkPopover() {
        linkPopoverController?.scheduleDismiss()
    }

    private func updateLink(newURL: String, newTitle: String, range: NSRange) {
        guard let textStorage = textStorage,
              range.location + range.length <= textStorage.length else { return }
        textStorage.beginEditing()

        // Update the URL attribute
        if let url = URL(string: newURL) {
            textStorage.addAttribute(.link, value: url, range: range)
        } else {
            textStorage.addAttribute(.link, value: newURL, range: range)
        }

        // Update the display text if title changed
        let currentText = (textStorage.string as NSString).substring(with: range)
        if newTitle != currentText && !newTitle.isEmpty {
            let attrs = textStorage.attributes(at: range.location, effectiveRange: nil)
            let replacement = NSAttributedString(string: newTitle, attributes: attrs)
            textStorage.replaceCharacters(in: range, with: replacement)
        }

        textStorage.endEditing()
        onTextChange?()
    }

    // MARK: - Keyboard Shortcuts

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard event.modifierFlags.contains(.command) else {
            return super.performKeyEquivalent(with: event)
        }

        let key = event.charactersIgnoringModifiers ?? ""

        switch key {
        case "b":
            toggleBold()
            return true
        case "i":
            toggleItalic()
            return true
        case "u":
            toggleUnderline()
            return true
        case "s":
            forceSave?()
            return true
        case "n":
            resetToNormal()
            return true
        case "1", "2", "3", "4", "5", "6":
            if let level = Int(key) {
                toggleHeading(level: level)
                return true
            }
        default:
            break
        }

        return super.performKeyEquivalent(with: event)
    }

    // MARK: - Formatting Toggles

    private func toggleBold() {
        guard let textStorage = textStorage else { return }
        let range = selectedRange()
        guard range.length > 0 else {
            // Toggle typing attributes
            var attrs = typingAttributes
            let font = attrs[.font] as? NSFont ?? Theme.bodyFont
            let isBold = font.fontDescriptor.symbolicTraits.contains(.bold)
            let isItalic = font.fontDescriptor.symbolicTraits.contains(.italic)
            if isBold {
                attrs[.font] = isItalic ? Theme.italicBodyFont : Theme.bodyFont
            } else {
                attrs[.font] = isItalic ? Theme.boldItalicBodyFont : Theme.boldBodyFont
            }
            typingAttributes = attrs
            return
        }

        textStorage.beginEditing()
        textStorage.enumerateAttribute(.font, in: range) { value, attrRange, _ in
            let font = value as? NSFont ?? Theme.bodyFont
            let isBold = font.fontDescriptor.symbolicTraits.contains(.bold)
            let isItalic = font.fontDescriptor.symbolicTraits.contains(.italic)
            let newFont: NSFont
            if isBold {
                newFont = isItalic ? Theme.italicBodyFont : Theme.bodyFont
            } else {
                newFont = isItalic ? Theme.boldItalicBodyFont : Theme.boldBodyFont
            }
            textStorage.addAttribute(.font, value: newFont, range: attrRange)
        }
        textStorage.endEditing()
        typingAttributes = Theme.bodyAttributes
        onTextChange?()
    }

    private func toggleItalic() {
        guard let textStorage = textStorage else { return }
        let range = selectedRange()
        guard range.length > 0 else {
            var attrs = typingAttributes
            let font = attrs[.font] as? NSFont ?? Theme.bodyFont
            let isBold = font.fontDescriptor.symbolicTraits.contains(.bold)
            let isItalic = font.fontDescriptor.symbolicTraits.contains(.italic)
            if isItalic {
                attrs[.font] = isBold ? Theme.boldBodyFont : Theme.bodyFont
            } else {
                attrs[.font] = isBold ? Theme.boldItalicBodyFont : Theme.italicBodyFont
            }
            typingAttributes = attrs
            return
        }

        textStorage.beginEditing()
        textStorage.enumerateAttribute(.font, in: range) { value, attrRange, _ in
            let font = value as? NSFont ?? Theme.bodyFont
            let isBold = font.fontDescriptor.symbolicTraits.contains(.bold)
            let isItalic = font.fontDescriptor.symbolicTraits.contains(.italic)
            let newFont: NSFont
            if isItalic {
                newFont = isBold ? Theme.boldBodyFont : Theme.bodyFont
            } else {
                newFont = isBold ? Theme.boldItalicBodyFont : Theme.italicBodyFont
            }
            textStorage.addAttribute(.font, value: newFont, range: attrRange)
        }
        textStorage.endEditing()
        typingAttributes = Theme.bodyAttributes
        onTextChange?()
    }

    private func toggleUnderline() {
        guard let textStorage = textStorage else { return }
        let range = selectedRange()
        guard range.length > 0 else {
            var attrs = typingAttributes
            let current = (attrs[.underlineStyle] as? Int) ?? 0
            attrs[.underlineStyle] = current == 0 ? NSUnderlineStyle.single.rawValue : 0
            typingAttributes = attrs
            return
        }

        textStorage.beginEditing()
        let currentVal = textStorage.attribute(.underlineStyle, at: range.location, effectiveRange: nil) as? Int ?? 0
        let newVal = currentVal == 0 ? NSUnderlineStyle.single.rawValue : 0
        textStorage.addAttribute(.underlineStyle, value: newVal, range: range)
        textStorage.endEditing()
        typingAttributes = Theme.bodyAttributes
        onTextChange?()
    }

    private func resetToNormal() {
        guard let textStorage = textStorage else { return }
        let range = selectedRange()

        if range.length == 0 {
            // No selection — reset the current paragraph
            let paragraphRange = (textStorage.string as NSString).paragraphRange(for: range)
            textStorage.beginEditing()
            textStorage.setAttributes(Theme.bodyAttributes, range: paragraphRange)
            textStorage.endEditing()
        } else {
            textStorage.beginEditing()
            textStorage.setAttributes(Theme.bodyAttributes, range: range)
            textStorage.endEditing()
        }

        typingAttributes = Theme.bodyAttributes
        onTextChange?()
    }

    private func toggleHeading(level: Int) {
        guard let textStorage = textStorage else { return }
        let range = selectedRange()
        let paragraphRange = (textStorage.string as NSString).paragraphRange(for: range)

        // Determine current level without throwing bounds exception
        var currentLevel: Int? = nil
        let checkLocation = paragraphRange.location
        if checkLocation < textStorage.length {
            currentLevel = textStorage.attribute(Theme.headingLevelKey, at: checkLocation, effectiveRange: nil) as? Int
        } else {
            currentLevel = typingAttributes[Theme.headingLevelKey] as? Int
        }

        if paragraphRange.length > 0 {
            textStorage.beginEditing()
            if currentLevel == level {
                // Remove heading — revert to body
                textStorage.removeAttribute(Theme.headingLevelKey, range: paragraphRange)
                textStorage.addAttribute(.font, value: Theme.bodyFont, range: paragraphRange)
                textStorage.addAttribute(.foregroundColor, value: Theme.textColor, range: paragraphRange)
                textStorage.addAttribute(.paragraphStyle, value: Theme.bodyParagraphStyle, range: paragraphRange)
            } else {
                // Apply heading
                textStorage.addAttribute(Theme.headingLevelKey, value: level, range: paragraphRange)
                textStorage.addAttribute(.font, value: Theme.headingFont(level: level), range: paragraphRange)
                textStorage.addAttribute(.foregroundColor, value: Theme.headingColor, range: paragraphRange)
                textStorage.addAttribute(.paragraphStyle, value: Theme.headingParagraphStyle(level: level), range: paragraphRange)
            }
            textStorage.endEditing()
        }

        // Always update typingAttributes so typing on an empty line works
        var attrs = typingAttributes
        if currentLevel == level {
            attrs.removeValue(forKey: Theme.headingLevelKey)
            attrs[.font] = Theme.bodyFont
            attrs[.foregroundColor] = Theme.textColor
            attrs[.paragraphStyle] = Theme.bodyParagraphStyle
        } else {
            attrs[Theme.headingLevelKey] = level
            attrs[.font] = Theme.headingFont(level: level)
            attrs[.foregroundColor] = Theme.headingColor
            attrs[.paragraphStyle] = Theme.headingParagraphStyle(level: level)
        }
        typingAttributes = attrs

        onTextChange?()
    }

    // MARK: - Smart Paste

    override func paste(_ sender: Any?) {
        let pasteboard = NSPasteboard.general

        // Check for image
        if let imageData = pasteboard.data(forType: .png) ?? pasteboard.data(forType: .tiff) {
            pasteImage(data: imageData)
            return
        }

        // Check for URL
        if let urlString = pasteboard.string(forType: .string),
           urlString.hasPrefix("http://") || urlString.hasPrefix("https://") {
            pasteURL(urlString)
            return
        }

        // Default paste — strip styling, insert as plain text
        if let plainText = pasteboard.string(forType: .string) {
            insertText(NSAttributedString(string: plainText, attributes: typingAttributes),
                       replacementRange: selectedRange())
            onTextChange?()
            return
        }
        super.paste(sender)
    }

    private func pasteImage(data: Data) {
        guard let image = NSImage(data: data) else { return }

        let home = FileManager.default.homeDirectoryForCurrentUser
        let notesDir = home.appendingPathComponent("notes")
        let timestamp = Int(Date().timeIntervalSince1970 * 1000)
        let filename = "image-\(timestamp).png"
        let filePath = notesDir.appendingPathComponent(filename)

        // Convert to PNG and save
        guard let tiffData = image.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffData),
              let pngData = bitmapRep.representation(using: .png, properties: [:]) else { return }

        do {
            try pngData.write(to: filePath)
        } catch {
            return
        }

        let attachment = NSTextAttachment()
        let maxWidth: CGFloat = 500
        let scale = image.size.width > maxWidth ? maxWidth / image.size.width : 1.0
        let size = NSSize(width: image.size.width * scale, height: image.size.height * scale)
        attachment.image = image
        attachment.bounds = CGRect(origin: .zero, size: size)

        let attrStr = NSMutableAttributedString(attachment: attachment)
        let imageMarkdownKey = NSAttributedString.Key("NotesApp.imageMarkdown")
        attrStr.addAttribute(imageMarkdownKey, value: "![](\(filename))",
                             range: NSRange(location: 0, length: attrStr.length))

        insertText(attrStr, replacementRange: selectedRange())
        onTextChange?()
    }

    private func pasteURL(_ urlString: String) {
        let range = selectedRange()

        if range.length > 0 {
            // Wrap selection as a link
            guard let textStorage = textStorage else { return }
            textStorage.beginEditing()
            if let url = URL(string: urlString) {
                textStorage.addAttribute(.link, value: url, range: range)
            } else {
                textStorage.addAttribute(.link, value: urlString, range: range)
            }
            textStorage.addAttribute(.foregroundColor, value: Theme.linkColor, range: range)
            textStorage.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: range)
            textStorage.endEditing()
        } else {
            // Insert as a styled link
            var attrs = typingAttributes
            attrs[.foregroundColor] = Theme.linkColor
            attrs[.underlineStyle] = NSUnderlineStyle.single.rawValue
            if let url = URL(string: urlString) {
                attrs[.link] = url
            } else {
                attrs[.link] = urlString
            }
            let linkStr = NSAttributedString(string: urlString, attributes: attrs)
            insertText(linkStr, replacementRange: range)
        }
        onTextChange?()
    }

    // MARK: - List Continuation

    override func insertNewline(_ sender: Any?) {
        guard let textStorage = textStorage else {
            super.insertNewline(sender)
            return
        }

        let cursorLocation = selectedRange().location
        let lineRange = (textStorage.string as NSString).lineRange(for: NSRange(location: cursorLocation, length: 0))
        let lineText = (textStorage.string as NSString).substring(with: lineRange).trimmingCharacters(in: .newlines)

        // Check unordered list
        if lineText.hasPrefix("- ") {
            let content = String(lineText.dropFirst(2))
            if content.trimmingCharacters(in: .whitespaces).isEmpty {
                // Empty list item — remove the marker
                let deleteRange = NSRange(location: lineRange.location, length: lineText.count)
                textStorage.replaceCharacters(in: deleteRange, with: "")
                onTextChange?()
                return
            }
            super.insertNewline(sender)
            let marker = NSAttributedString(string: "- ", attributes: listInsertionAttributes(unordered: true))
            insertText(marker, replacementRange: selectedRange())
            onTextChange?()
            return
        }

        // Check ordered list
        let orderedPattern = #"^(\d+)\.\s"#
        if let regex = try? NSRegularExpression(pattern: orderedPattern),
           let match = regex.firstMatch(in: lineText, range: NSRange(lineText.startIndex..., in: lineText)),
           let numRange = Range(match.range(at: 1), in: lineText),
           let num = Int(lineText[numRange]) {

            let markerEndIndex = lineText.index(numRange.upperBound, offsetBy: 2)
            let content = String(lineText[markerEndIndex...])
            if content.trimmingCharacters(in: .whitespaces).isEmpty {
                let deleteRange = NSRange(location: lineRange.location, length: lineText.count)
                textStorage.replaceCharacters(in: deleteRange, with: "")
                onTextChange?()
                return
            }

            super.insertNewline(sender)
            let nextNum = num + 1
            let marker = NSAttributedString(string: "\(nextNum). ", attributes: listInsertionAttributes(unordered: false))
            insertText(marker, replacementRange: selectedRange())
            onTextChange?()
            return
        }

        super.insertNewline(sender)
    }

    private func listInsertionAttributes(unordered: Bool) -> [NSAttributedString.Key: Any] {
        var attrs = Theme.bodyAttributes
        attrs[.paragraphStyle] = Theme.listParagraphStyle
        if unordered {
            attrs[Theme.listTypeKey] = "unordered"
        } else {
            attrs[Theme.listTypeKey] = "ordered"
        }
        return attrs
    }
}
