import SwiftUI
import AppKit

@MainActor
final class SettingsWindowManager {
    static let shared = SettingsWindowManager()

    private var window: NSWindow?

    private init() {}

    func show() {
        if window == nil {
            let contentView = SettingsView()
            let hostingView = NSHostingView(rootView: contentView)

            window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 540, height: 560),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            window?.contentView = hostingView
            window?.title = "Dock Toggle Settings"
            window?.level = .floating
            window?.isReleasedWhenClosed = false
            window?.identifier = NSUserInterfaceItemIdentifier("settings")
        }
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
