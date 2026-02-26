import AppKit

enum Theme {
    // MARK: - Fonts

    static let bodySize: CGFloat = 16
    static let bodyFont = NSFont.systemFont(ofSize: bodySize, weight: .regular)
    static let boldBodyFont = NSFont.systemFont(ofSize: bodySize, weight: .bold)
    static let italicBodyFont: NSFont = {
        let descriptor = bodyFont.fontDescriptor.withSymbolicTraits(.italic)
        return NSFont(descriptor: descriptor, size: bodySize) ?? bodyFont
    }()
    static let boldItalicBodyFont: NSFont = {
        let descriptor = boldBodyFont.fontDescriptor.withSymbolicTraits(.italic)
        return NSFont(descriptor: descriptor, size: bodySize) ?? boldBodyFont
    }()

    static func headingFont(level: Int) -> NSFont {
        let sizes: [CGFloat] = [28, 24, 20, 18, 16, 14]
        let size = sizes[min(max(level - 1, 0), sizes.count - 1)]
        return NSFont.systemFont(ofSize: size, weight: .bold)
    }

    // MARK: - Colors

    static let backgroundColor = NSColor(calibratedRed: 0.96, green: 0.97, blue: 0.98, alpha: 1.0)
    static let textColor = NSColor(calibratedRed: 0.33, green: 0.38, blue: 0.44, alpha: 1.0)
    static let linkColor = NSColor(calibratedRed: 0.20, green: 0.50, blue: 0.85, alpha: 1.0)
    static let headingColor = NSColor(calibratedRed: 0.22, green: 0.27, blue: 0.33, alpha: 1.0)

    // MARK: - Spacing

    static let lineSpacing: CGFloat = 10.0  // adds to natural line height for generous spacing
    static let paragraphSpacing: CGFloat = 16.0
    static let textContainerInsetWidth: CGFloat = 60.0
    static let textContainerInsetHeight: CGFloat = 20.0

    // MARK: - Paragraph Styles

    static var bodyParagraphStyle: NSMutableParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.lineSpacing = lineSpacing
        style.paragraphSpacing = paragraphSpacing
        return style
    }

    static func headingParagraphStyle(level: Int) -> NSMutableParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.lineSpacing = 4.0
        style.paragraphSpacingBefore = level <= 2 ? 16.0 : 10.0
        style.paragraphSpacing = level <= 2 ? 10.0 : 6.0
        return style
    }

    static var listParagraphStyle: NSMutableParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.lineSpacing = lineSpacing
        style.paragraphSpacing = 4.0
        style.headIndent = 24.0
        style.firstLineHeadIndent = 0
        let tabStop = NSTextTab(textAlignment: .left, location: 24.0)
        style.tabStops = [tabStop]
        return style
    }

    // MARK: - Default Attributes

    static var bodyAttributes: [NSAttributedString.Key: Any] {
        [
            .font: bodyFont,
            .foregroundColor: textColor,
            .paragraphStyle: bodyParagraphStyle,
        ]
    }

    // MARK: - Custom Attribute Keys

    static let headingLevelKey = NSAttributedString.Key("NotesApp.headingLevel")
    static let listTypeKey = NSAttributedString.Key("NotesApp.listType")
    static let listIndexKey = NSAttributedString.Key("NotesApp.listIndex")
    static let tableMarkdownKey = NSAttributedString.Key("NotesApp.tableMarkdown")
}
