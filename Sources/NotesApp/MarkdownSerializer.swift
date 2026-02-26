import AppKit

struct MarkdownSerializer {

    func serialize(_ attributedString: NSAttributedString) -> String {
        var lines: [String] = []
        let string = attributedString.string

        // Split into paragraphs by newline
        var paragraphStart = string.startIndex

        while paragraphStart < string.endIndex {
            let remaining = string[paragraphStart...]
            let paragraphEnd: String.Index
            if let newlineIndex = remaining.firstIndex(of: "\n") {
                paragraphEnd = newlineIndex
            } else {
                paragraphEnd = string.endIndex
            }

            let paragraphRange = paragraphStart..<paragraphEnd
            let nsRange = NSRange(paragraphRange, in: string)

            if nsRange.length == 0 {
                lines.append("")
            } else {
                let paragraphAttrStr = attributedString.attributedSubstring(from: nsRange)
                let line = serializeParagraph(paragraphAttrStr)
                lines.append(line)
            }

            if paragraphEnd < string.endIndex {
                paragraphStart = string.index(after: paragraphEnd)
            } else {
                break
            }
        }

        // Clean up trailing empty lines
        while lines.last == "" && lines.count > 1 {
            lines.removeLast()
        }

        return lines.joined(separator: "\n")
    }

    private func serializeParagraph(_ attrStr: NSAttributedString) -> String {
        let length = attrStr.length
        guard length > 0 else { return "" }

        // Check for heading level
        var headingLevel: Int?
        if let level = attrStr.attribute(Theme.headingLevelKey, at: 0, effectiveRange: nil) as? Int {
            headingLevel = level
        }

        // Check for list type
        var listType: String?
        var listIndex: Int?
        if let type = attrStr.attribute(Theme.listTypeKey, at: 0, effectiveRange: nil) as? String {
            listType = type
            listIndex = attrStr.attribute(Theme.listIndexKey, at: 0, effectiveRange: nil) as? Int
        }

        // Serialize inline content
        let inlineContent = serializeInlineContent(attrStr, skipListMarker: listType != nil)

        // Build the line
        if let level = headingLevel {
            let prefix = String(repeating: "#", count: level) + " "
            return prefix + inlineContent
        } else if let type = listType {
            if type == "unordered" {
                return "- " + inlineContent
            } else {
                let idx = listIndex ?? 1
                return "\(idx). " + inlineContent
            }
        } else {
            return inlineContent
        }
    }

    private func serializeInlineContent(_ attrStr: NSAttributedString, skipListMarker: Bool) -> String {
        var result = ""
        let length = attrStr.length
        var index = 0

        // If this is a list item, skip the marker (e.g., "- \t" or "1.\t")
        if skipListMarker {
            let text = attrStr.string
            if let tabIndex = text.firstIndex(of: "\t") {
                let skipTo = text.distance(from: text.startIndex, to: tabIndex) + 1
                index = skipTo
            }
        }

        while index < length {
            var effectiveRange = NSRange()

            // Check for table attachment
            if let tableMarkdown = attrStr.attribute(Theme.tableMarkdownKey, at: index, effectiveRange: &effectiveRange) as? String {
                result += tableMarkdown
                index = NSMaxRange(effectiveRange)
                continue
            }

            // Check for image attachment
            let imageMarkdownKey = NSAttributedString.Key("NotesApp.imageMarkdown")
            if let imageMarkdown = attrStr.attribute(imageMarkdownKey, at: index, effectiveRange: &effectiveRange) as? String {
                result += imageMarkdown
                index = NSMaxRange(effectiveRange)
                continue
            }

            // Check for hr attachment
            let hrMarkdownKey = NSAttributedString.Key("NotesApp.hrMarkdown")
            if let hrMarkdown = attrStr.attribute(hrMarkdownKey, at: index, effectiveRange: &effectiveRange) as? String {
                result += hrMarkdown
                index = NSMaxRange(effectiveRange)
                continue
            }

            // Check for text attachment (image without stored markdown)
            if attrStr.attribute(.attachment, at: index, effectiveRange: &effectiveRange) != nil {
                index = NSMaxRange(effectiveRange)
                continue
            }

            let attrs = attrStr.attributes(at: index, effectiveRange: &effectiveRange)
            let runRange = effectiveRange
            let runText = (attrStr.string as NSString).substring(with: runRange)

            // Skip empty runs
            if runText.isEmpty {
                index = NSMaxRange(runRange)
                continue
            }

            var text = runText

            // Check link
            let linkURL: String? = {
                if let url = attrs[.link] as? URL {
                    return url.absoluteString
                } else if let str = attrs[.link] as? String {
                    return str
                }
                return nil
            }()

            // Check formatting traits
            let font = attrs[.font] as? NSFont
            let isBold = font?.fontDescriptor.symbolicTraits.contains(.bold) ?? false
            let isItalic = font?.fontDescriptor.symbolicTraits.contains(.italic) ?? false
            let isUnderline = (attrs[.underlineStyle] as? Int).map { $0 != 0 } ?? false

            // Apply inline markdown
            if isUnderline && linkURL == nil {
                text = "<u>" + text + "</u>"
            }
            if isBold && isItalic {
                text = "***" + text + "***"
            } else if isBold {
                // Don't apply bold markers to headings (they're inherently bold)
                if attrStr.attribute(Theme.headingLevelKey, at: index, effectiveRange: nil) == nil {
                    text = "**" + text + "**"
                }
            } else if isItalic {
                text = "*" + text + "*"
            }

            if let url = linkURL {
                text = "[\(text)](\(url))"
            }

            result += text
            index = NSMaxRange(runRange)
        }

        return result
    }
}
