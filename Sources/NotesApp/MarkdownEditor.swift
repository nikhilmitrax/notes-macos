import SwiftUI
import AppKit

struct MarkdownEditor: NSViewRepresentable {
    private let filePath: URL = {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent("notes/main.md")
    }()

    func makeCoordinator() -> Coordinator {
        Coordinator(filePath: filePath)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.drawsBackground = false
        scrollView.backgroundColor = .clear
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder

        let textStorage = NSTextStorage()
        let layoutManager = NSLayoutManager()
        textStorage.addLayoutManager(layoutManager)

        let textContainer = NSTextContainer()
        textContainer.widthTracksTextView = true
        textContainer.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        layoutManager.addTextContainer(textContainer)

        let textView = MarkdownTextView(frame: .zero, textContainer: textContainer)
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.drawsBackground = false // Make text view transparent
        textView.delegate = context.coordinator

        textView.onTextChange = { [weak coordinator = context.coordinator] in
            coordinator?.scheduleSave()
        }
        textView.forceSave = { [weak coordinator = context.coordinator] in
            coordinator?.saveNow()
        }

        scrollView.documentView = textView
        context.coordinator.textView = textView

        // Load initial content
        context.coordinator.loadFile()

        // Make text view first responder once the window is ready
        DispatchQueue.main.async {
            textView.window?.makeFirstResponder(textView)
        }

        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        // No reactive updates needed — the text view manages its own state
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        let filePath: URL
        weak var textView: MarkdownTextView?
        private let parser = MarkdownParser()
        private let serializer = MarkdownSerializer()
        private var saveTimer: Timer?
        private var isLoading = false

        init(filePath: URL) {
            self.filePath = filePath
        }

        func loadFile() {
            isLoading = true
            defer { isLoading = false }

            guard let textView = textView else { return }

            let markdown: String
            do {
                markdown = try String(contentsOf: filePath, encoding: .utf8)
            } catch {
                markdown = ""
            }

            let attributed = parser.parse(markdown)
            textView.textStorage?.setAttributedString(attributed)
            textView.typingAttributes = Theme.bodyAttributes
        }

        func scheduleSave() {
            saveTimer?.invalidate()
            saveTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
                self?.saveNow()
            }
        }

        func saveNow() {
            saveTimer?.invalidate()
            guard let textView = textView,
                  let textStorage = textView.textStorage else { return }

            let markdown = serializer.serialize(textStorage)
            do {
                try markdown.write(to: filePath, atomically: true, encoding: .utf8)
            } catch {
                NSLog("Failed to save: \(error)")
            }
        }

        func textDidChange(_ notification: Notification) {
            guard !isLoading else { return }
            scheduleSave()
        }
    }
}
