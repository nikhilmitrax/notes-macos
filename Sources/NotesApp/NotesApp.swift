import SwiftUI
import HotKey
import ServiceManagement

@main
struct NotesApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 400, minHeight: 300)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 700, height: 900)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private var hotKey: HotKey?
    private var windowDelegateProxy: WindowDelegateProxy?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        NSApp.activate(ignoringOtherApps: true)
        ensureNotesDirectory()
        configureWindow()
        setupHotKey()
        // Delay to avoid interfering with initial window display
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.registerAsLoginItem()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    private func registerAsLoginItem() {
        if SMAppService.mainApp.status == .notRegistered {
            try? SMAppService.mainApp.register()
        }
    }

    private func setupHotKey() {
        // cmd + ctrl + n
        hotKey = HotKey(key: .n, modifiers: [.command, .control])
        hotKey?.keyDownHandler = { [weak self] in
            self?.toggleAppVisibility()
        }
    }

    private func toggleAppVisibility() {
        if NSApp.isActive && NSApp.isHidden == false {
            NSApp.hide(nil)
        } else {
            NSApp.unhide(nil)
            NSApp.activate(ignoringOtherApps: true)
            if let window = NSApplication.shared.windows.first {
                window.makeKeyAndOrderFront(nil)
            }
        }
    }

    private func ensureNotesDirectory() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let notesDir = home.appendingPathComponent("notes")
        let mainFile = notesDir.appendingPathComponent("main.md")

        if !FileManager.default.fileExists(atPath: notesDir.path) {
            try? FileManager.default.createDirectory(at: notesDir, withIntermediateDirectories: true)
        }
        if !FileManager.default.fileExists(atPath: mainFile.path) {
            try? "".write(to: mainFile, atomically: true, encoding: .utf8)
        }
    }

    private func configureWindow() {
        DispatchQueue.main.async {
            if let window = NSApplication.shared.windows.first {
                window.title = "Notes"
                window.titlebarAppearsTransparent = true
                window.titleVisibility = .hidden
                window.backgroundColor = .clear
                window.isOpaque = false
                window.isMovableByWindowBackground = true

                // Proxy forwards all calls to SwiftUI's original delegate,
                // only intercepting windowShouldClose to hide instead of close.
                let proxy = WindowDelegateProxy()
                proxy.original = window.delegate
                self.windowDelegateProxy = proxy
                window.delegate = proxy
            }
        }
    }
}

/// Wraps SwiftUI's window delegate so we can intercept `windowShouldClose`
/// without discarding SwiftUI's own delegate behaviour.
private class WindowDelegateProxy: NSObject, NSWindowDelegate {
    weak var original: AnyObject?

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        NSApp.hide(nil)
        return false
    }

    override func responds(to aSelector: Selector!) -> Bool {
        if super.responds(to: aSelector) { return true }
        if let o = original as? NSObject, o.responds(to: aSelector) { return true }
        return false
    }

    override func forwardingTarget(for aSelector: Selector!) -> Any? {
        if let o = original as? NSObject, o.responds(to: aSelector) {
            return o
        }
        return super.forwardingTarget(for: aSelector)
    }
}
