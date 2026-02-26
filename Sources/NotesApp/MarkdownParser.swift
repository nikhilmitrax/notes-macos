import AppKit

struct MarkdownParser {

    func parse(_ markdown: String) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let lines = markdown.components(separatedBy: "\n")
        var i = 0

        while i < lines.count {
            let line = lines[i]

            if i > 0 {
                result.append(NSAttributedString(string: "\n", attributes: Theme.bodyAttributes))
            }

            if line.isEmpty {
                // Blank line — just the newline above suffices (paragraph break)
                i += 1
                continue
            }

            // Table block: header row + separator + optional data rows
            if isTableRow(line) && i + 1 < lines.count && isTableSeparator(lines[i + 1]) {
                var tableLines = [line]
                var j = i + 1
                while j < lines.count && (isTableRow(lines[j]) || isTableSeparator(lines[j])) {
                    tableLines.append(lines[j])
                    j += 1
                }
                result.append(parseTable(tableLines))
                i = j
                continue
            }

            if let (level, content) = parseHeading(line) {
                let attrStr = applyInlineFormatting(to: content, baseAttributes: headingAttributes(level: level))
                result.append(attrStr)
            } else if line == "---" {
                let attrStr = createHorizontalRule()
                result.append(attrStr)
            } else if let (content, index) = parseOrderedListItem(line) {
                let marker = NSAttributedString(string: "\(index).\t", attributes: listAttributes())
                let attrStr = applyInlineFormatting(to: content, baseAttributes: listAttributes())
                let combined = NSMutableAttributedString()
                combined.append(marker)
                combined.append(attrStr)
                combined.addAttribute(Theme.listTypeKey, value: "ordered", range: NSRange(location: 0, length: combined.length))
                combined.addAttribute(Theme.listIndexKey, value: index, range: NSRange(location: 0, length: combined.length))
                result.append(combined)
            } else if let content = parseUnorderedListItem(line) {
                let marker = NSAttributedString(string: "-\t", attributes: listAttributes())
                let attrStr = applyInlineFormatting(to: content, baseAttributes: listAttributes())
                let combined = NSMutableAttributedString()
                combined.append(marker)
                combined.append(attrStr)
                combined.addAttribute(Theme.listTypeKey, value: "unordered", range: NSRange(location: 0, length: combined.length))
                result.append(combined)
            } else {
                let attrStr = applyInlineFormatting(to: line, baseAttributes: Theme.bodyAttributes)
                result.append(attrStr)
            }

            i += 1
        }

        return result
    }

    // MARK: - Block Parsing

    private func createHorizontalRule() -> NSAttributedString {
        let attachment = NSTextAttachment()
        let width: CGFloat = 1000 // Large fixed width to span most windows
        let height: CGFloat = 1
        
        let image = NSImage(size: NSSize(width: width, height: height))
        image.lockFocus()
        Theme.textColor.withAlphaComponent(0.2).set()
        NSRect(x: 0, y: 0, width: width, height: height).fill()
        image.unlockFocus()
        
        attachment.image = image
        attachment.bounds = CGRect(x: 0, y: 4, width: width, height: height)
        
        let attrStr = NSMutableAttributedString(attachment: attachment)
        
        let style = NSMutableParagraphStyle()
        style.paragraphSpacingBefore = 12
        style.paragraphSpacing = 12
        attrStr.addAttribute(.paragraphStyle, value: style, range: NSRange(location: 0, length: attrStr.length))
        
        let hrMarkdownKey = NSAttributedString.Key("NotesApp.hrMarkdown")
        attrStr.addAttribute(hrMarkdownKey, value: "---", range: NSRange(location: 0, length: attrStr.length))
        
        return attrStr
    }

    private func parseHeading(_ line: String) -> (level: Int, content: String)? {
        let pattern = #"^(#{1,6})\s+(.+)$"#
        guard let match = line.range(of: pattern, options: .regularExpression) else { return nil }
        let matched = String(line[match])
        let hashes = matched.prefix(while: { $0 == "#" })
        let level = hashes.count
        let content = String(matched.dropFirst(level).drop(while: { $0 == " " }))
        return (level, content)
    }

    private func parseUnorderedListItem(_ line: String) -> String? {
        let trimmed = line
        if trimmed.hasPrefix("- ") {
            return String(trimmed.dropFirst(2))
        }
        return nil
    }

    private func parseOrderedListItem(_ line: String) -> (content: String, index: Int)? {
        let pattern = #"^(\d+)\.\s+(.+)$"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
              let indexRange = Range(match.range(at: 1), in: line),
              let contentRange = Range(match.range(at: 2), in: line),
              let index = Int(line[indexRange])
        else { return nil }
        return (String(line[contentRange]), index)
    }

    // MARK: - Inline Formatting

    private func applyInlineFormatting(to text: String, baseAttributes: [NSAttributedString.Key: Any]) -> NSAttributedString {
        let result = NSMutableAttributedString(string: text, attributes: baseAttributes)
        let baseFont = baseAttributes[.font] as? NSFont ?? Theme.bodyFont

        applyImages(to: result)
        applyLinks(to: result, baseAttributes: baseAttributes)
        applyBoldItalic(to: result, baseFont: baseFont)
        applyBold(to: result, baseFont: baseFont)
        applyItalic(to: result, baseFont: baseFont)
        applyUnderline(to: result)

        return result
    }

    private func applyBold(to attrStr: NSMutableAttributedString, baseFont: NSFont) {
        let pattern = #"\*\*(.+?)\*\*"#
        applyPattern(pattern, to: attrStr, markerLength: 2) { range in
            let currentFont = attrStr.attribute(.font, at: range.location, effectiveRange: nil) as? NSFont ?? baseFont
            let isItalic = currentFont.fontDescriptor.symbolicTraits.contains(.italic)
            let newFont: NSFont
            if isItalic {
                newFont = Theme.boldItalicBodyFont
            } else if baseFont == Theme.bodyFont || baseFont == Theme.boldBodyFont {
                newFont = Theme.boldBodyFont
            } else {
                // Heading or other — add bold trait
                let descriptor = currentFont.fontDescriptor.withSymbolicTraits(
                    currentFont.fontDescriptor.symbolicTraits.union(.bold))
                newFont = NSFont(descriptor: descriptor, size: currentFont.pointSize) ?? currentFont
            }
            attrStr.addAttribute(.font, value: newFont, range: range)
        }
    }

    private func applyItalic(to attrStr: NSMutableAttributedString, baseFont: NSFont) {
        let pattern = #"(?<!\*)\*(?!\*)(.+?)(?<!\*)\*(?!\*)"#
        applyPattern(pattern, to: attrStr, markerLength: 1) { range in
            let currentFont = attrStr.attribute(.font, at: range.location, effectiveRange: nil) as? NSFont ?? baseFont
            let isBold = currentFont.fontDescriptor.symbolicTraits.contains(.bold)
            let newFont: NSFont
            if isBold {
                newFont = Theme.boldItalicBodyFont
            } else if baseFont == Theme.bodyFont || baseFont == Theme.italicBodyFont {
                newFont = Theme.italicBodyFont
            } else {
                let descriptor = currentFont.fontDescriptor.withSymbolicTraits(
                    currentFont.fontDescriptor.symbolicTraits.union(.italic))
                newFont = NSFont(descriptor: descriptor, size: currentFont.pointSize) ?? currentFont
            }
            attrStr.addAttribute(.font, value: newFont, range: range)
        }
    }

    private func applyBoldItalic(to attrStr: NSMutableAttributedString, baseFont: NSFont) {
        let pattern = #"\*\*\*(.+?)\*\*\*"#
        applyPattern(pattern, to: attrStr, markerLength: 3) { range in
            let newFont: NSFont
            if baseFont == Theme.bodyFont || baseFont == Theme.boldItalicBodyFont {
                newFont = Theme.boldItalicBodyFont
            } else {
                let descriptor = baseFont.fontDescriptor.withSymbolicTraits(
                    baseFont.fontDescriptor.symbolicTraits.union([.bold, .italic]))
                newFont = NSFont(descriptor: descriptor, size: baseFont.pointSize) ?? baseFont
            }
            attrStr.addAttribute(.font, value: newFont, range: range)
        }
    }

    private func applyUnderline(to attrStr: NSMutableAttributedString) {
        let pattern = #"<u>(.+?)</u>"#
        let string = attrStr.string as NSString
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return }
        let matches = regex.matches(in: attrStr.string, range: NSRange(location: 0, length: string.length))

        for match in matches.reversed() {
            let fullRange = match.range
            let contentRange = match.range(at: 1)
            let content = string.substring(with: contentRange)

            let attrs = attrStr.attributes(at: contentRange.location, effectiveRange: nil)
            let replacement = NSMutableAttributedString(string: content, attributes: attrs)
            replacement.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue,
                                     range: NSRange(location: 0, length: content.count))
            attrStr.replaceCharacters(in: fullRange, with: replacement)
        }
    }

    private func applyLinks(to attrStr: NSMutableAttributedString, baseAttributes: [NSAttributedString.Key: Any]) {
        let pattern = #"\[([^\]]+)\]\(([^)]+)\)"#
        let string = attrStr.string as NSString
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return }
        let matches = regex.matches(in: attrStr.string, range: NSRange(location: 0, length: string.length))

        for match in matches.reversed() {
            let fullRange = match.range
            let textRange = match.range(at: 1)
            let urlRange = match.range(at: 2)
            let text = string.substring(with: textRange)
            let urlString = string.substring(with: urlRange)

            var attrs = baseAttributes
            attrs[.foregroundColor] = Theme.linkColor
            attrs[.underlineStyle] = NSUnderlineStyle.single.rawValue
            if let url = URL(string: urlString) {
                attrs[.link] = url
            } else {
                attrs[.link] = urlString
            }
            let replacement = NSAttributedString(string: text, attributes: attrs)
            attrStr.replaceCharacters(in: fullRange, with: replacement)
        }
    }

    private func applyImages(to attrStr: NSMutableAttributedString) {
        let pattern = #"!\[([^\]]*)\]\(([^)]+)\)"#
        let string = attrStr.string as NSString
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return }
        let matches = regex.matches(in: attrStr.string, range: NSRange(location: 0, length: string.length))

        for match in matches.reversed() {
            let fullRange = match.range
            let altRange = match.range(at: 1)
            let pathRange = match.range(at: 2)
            let alt = string.substring(with: altRange)
            let pathStr = string.substring(with: pathRange)

            let imagePath: String
            if pathStr.hasPrefix("/") || pathStr.hasPrefix("~") {
                imagePath = (pathStr as NSString).expandingTildeInPath
            } else {
                let home = FileManager.default.homeDirectoryForCurrentUser
                imagePath = home.appendingPathComponent("notes").appendingPathComponent(pathStr).path
            }

            guard let image = NSImage(contentsOfFile: imagePath) else {
                // Leave as text if image not found
                continue
            }

            let attachment = NSTextAttachment()
            let maxWidth: CGFloat = 500
            let scale = image.size.width > maxWidth ? maxWidth / image.size.width : 1.0
            let size = NSSize(width: image.size.width * scale, height: image.size.height * scale)
            attachment.image = image
            attachment.bounds = CGRect(origin: .zero, size: size)

            let attachmentStr = NSMutableAttributedString(attachment: attachment)
            // Store original markdown in a custom attribute for serialization
            let markdownKey = NSAttributedString.Key("NotesApp.imageMarkdown")
            attachmentStr.addAttribute(markdownKey, value: "![\(alt)](\(pathStr))",
                                       range: NSRange(location: 0, length: attachmentStr.length))
            attrStr.replaceCharacters(in: fullRange, with: attachmentStr)
        }
    }

    // MARK: - Helpers

    private func applyPattern(_ pattern: String, to attrStr: NSMutableAttributedString,
                              markerLength: Int, apply: (NSRange) -> Void) {
        let string = attrStr.string as NSString
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return }
        let matches = regex.matches(in: attrStr.string, range: NSRange(location: 0, length: string.length))

        for match in matches.reversed() {
            let fullRange = match.range
            let contentRange = match.range(at: 1)
            let content = string.substring(with: contentRange)

            // Preserve existing attributes from the content location
            let existingAttrs = attrStr.attributes(at: contentRange.location, effectiveRange: nil)
            let replacement = NSMutableAttributedString(string: content, attributes: existingAttrs)
            attrStr.replaceCharacters(in: fullRange, with: replacement)

            let newRange = NSRange(location: fullRange.location, length: content.count)
            apply(newRange)
        }
    }

    // MARK: - Table Support

    private func isTableRow(_ line: String) -> Bool {
        let t = line.trimmingCharacters(in: .whitespaces)
        return t.hasPrefix("|") && t.hasSuffix("|") && t.count > 2
    }

    private func isTableSeparator(_ line: String) -> Bool {
        let t = line.trimmingCharacters(in: .whitespaces)
        guard t.hasPrefix("|") && t.hasSuffix("|") else { return false }
        return t.allSatisfy { $0 == "|" || $0 == "-" || $0 == ":" || $0 == " " }
    }

    private func tableRowCells(_ line: String) -> [String] {
        var t = line.trimmingCharacters(in: .whitespaces)
        if t.hasPrefix("|") { t = String(t.dropFirst()) }
        if t.hasSuffix("|") { t = String(t.dropLast()) }
        return t.components(separatedBy: "|").map { $0.trimmingCharacters(in: .whitespaces) }
    }

    private func parseTable(_ lines: [String]) -> NSAttributedString {
        guard lines.count >= 2 else { return NSAttributedString() }
        let markdown = lines.joined(separator: "\n")
        let headers = tableRowCells(lines[0])
        let rows = lines.dropFirst(2)
            .filter { !isTableSeparator($0) }
            .map { tableRowCells($0) }
        return createTableAttachment(markdown: markdown, headers: headers, rows: Array(rows))
    }

    private func createTableAttachment(markdown: String, headers: [String], rows: [[String]]) -> NSAttributedString {
        let paddingH: CGFloat = 12
        let paddingV: CGFloat = 8
        let headerFont = Theme.boldBodyFont
        let bodyFont = Theme.bodyFont
        let colCount = headers.count
        guard colCount > 0 else { return NSAttributedString() }

        // Measure natural column widths from content
        var colWidths = [CGFloat](repeating: paddingH * 2 + 30, count: colCount)
        for (i, header) in headers.enumerated() {
            let w = (header as NSString).size(withAttributes: [.font: headerFont]).width
            colWidths[i] = max(colWidths[i], ceil(w) + paddingH * 2)
        }
        for row in rows {
            for (i, cell) in row.prefix(colCount).enumerated() {
                let w = (cell as NSString).size(withAttributes: [.font: bodyFont]).width
                colWidths[i] = max(colWidths[i], ceil(w) + paddingH * 2)
            }
        }

        // Scale down proportionally if wider than the content column
        let maxWidth: CGFloat = 560
        let naturalWidth = colWidths.reduce(0, +)
        if naturalWidth > maxWidth {
            let scale = maxWidth / naturalWidth
            colWidths = colWidths.map { floor($0 * scale) }
        }

        let tableWidth   = colWidths.reduce(0, +)
        let headerTextH  = ceil(headerFont.ascender - headerFont.descender)
        let bodyTextH    = ceil(bodyFont.ascender   - bodyFont.descender)
        let headerRowH   = headerTextH + paddingV * 2
        let dataRowH     = bodyTextH   + paddingV * 2
        let tableHeight  = headerRowH  + CGFloat(rows.count) * dataRowH

        // ── Render ──────────────────────────────────────────────────────────
        // NSImage uses bottom-left origin (y increases upward).
        // draw(in:) places text with its top at rect.maxY, so rects are built
        // with origin.y = visualTop - height in NSImage coordinates.
        let image = NSImage(size: NSSize(width: tableWidth, height: tableHeight))
        image.lockFocus()

        // Header background
        NSColor(calibratedRed: 0.89, green: 0.91, blue: 0.93, alpha: 1.0).setFill()
        NSRect(x: 0, y: tableHeight - headerRowH, width: tableWidth, height: headerRowH).fill()

        // Alternating data-row backgrounds
        let altBg = NSColor(calibratedRed: 0.97, green: 0.97, blue: 0.98, alpha: 1.0)
        for i in 0..<rows.count {
            (i % 2 == 0 ? NSColor.white : altBg).setFill()
            let y = tableHeight - headerRowH - CGFloat(i + 1) * dataRowH
            NSRect(x: 0, y: y, width: tableWidth, height: dataRowH).fill()
        }

        // Header cell text
        let headerAttrs: [NSAttributedString.Key: Any] = [.font: headerFont, .foregroundColor: Theme.headingColor]
        var colX: CGFloat = 0
        for (i, header) in headers.enumerated() {
            let rowY = tableHeight - headerRowH
            let rect = NSRect(x: colX + paddingH,
                              y: rowY + (headerRowH - headerTextH) / 2,
                              width: colWidths[i] - paddingH * 2,
                              height: headerTextH)
            NSAttributedString(string: header, attributes: headerAttrs).draw(in: rect)
            colX += colWidths[i]
        }

        // Data cell text
        let bodyAttrs: [NSAttributedString.Key: Any] = [.font: bodyFont, .foregroundColor: Theme.textColor]
        for (rowIdx, row) in rows.enumerated() {
            colX = 0
            let rowY = tableHeight - headerRowH - CGFloat(rowIdx + 1) * dataRowH
            for colIdx in 0..<colCount {
                let cell = colIdx < row.count ? row[colIdx] : ""
                let rect = NSRect(x: colX + paddingH,
                                  y: rowY + (dataRowH - bodyTextH) / 2,
                                  width: colWidths[colIdx] - paddingH * 2,
                                  height: bodyTextH)
                NSAttributedString(string: cell, attributes: bodyAttrs).draw(in: rect)
                colX += colWidths[colIdx]
            }
        }

        // Grid lines
        let gridPath = NSBezierPath()
        gridPath.lineWidth = 0.5
        gridPath.appendRect(NSRect(x: 0.25, y: 0.25, width: tableWidth - 0.5, height: tableHeight - 0.5))

        colX = 0
        for i in 0..<colCount - 1 {
            colX += colWidths[i]
            gridPath.move(to: NSPoint(x: colX, y: 0))
            gridPath.line(to: NSPoint(x: colX, y: tableHeight))
        }
        for i in 0..<rows.count - 1 {
            let y = tableHeight - headerRowH - CGFloat(i + 1) * dataRowH
            gridPath.move(to: NSPoint(x: 0, y: y))
            gridPath.line(to: NSPoint(x: tableWidth, y: y))
        }
        Theme.textColor.withAlphaComponent(0.18).setStroke()
        gridPath.stroke()

        // Heavier header separator
        let sepPath = NSBezierPath()
        sepPath.lineWidth = 0.5
        let sepY = tableHeight - headerRowH
        sepPath.move(to: NSPoint(x: 0, y: sepY))
        sepPath.line(to: NSPoint(x: tableWidth, y: sepY))
        Theme.textColor.withAlphaComponent(0.35).setStroke()
        sepPath.stroke()

        image.unlockFocus()
        // ── End render ──────────────────────────────────────────────────────

        let attachment = NSTextAttachment()
        attachment.image = image
        attachment.bounds = CGRect(x: 0, y: 0, width: tableWidth, height: tableHeight)

        let attrStr = NSMutableAttributedString(attachment: attachment)
        attrStr.addAttribute(Theme.tableMarkdownKey, value: markdown,
                             range: NSRange(location: 0, length: attrStr.length))

        let style = NSMutableParagraphStyle()
        style.paragraphSpacingBefore = 8
        style.paragraphSpacing = 8
        attrStr.addAttribute(.paragraphStyle, value: style,
                             range: NSRange(location: 0, length: attrStr.length))
        return attrStr
    }

    // MARK: - Attributes helpers

    private func headingAttributes(level: Int) -> [NSAttributedString.Key: Any] {
        [
            .font: Theme.headingFont(level: level),
            .foregroundColor: Theme.headingColor,
            .paragraphStyle: Theme.headingParagraphStyle(level: level),
            Theme.headingLevelKey: level,
        ]
    }

    private func listAttributes() -> [NSAttributedString.Key: Any] {
        [
            .font: Theme.bodyFont,
            .foregroundColor: Theme.textColor,
            .paragraphStyle: Theme.listParagraphStyle,
        ]
    }
}
