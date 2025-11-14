import SwiftUI
import AppKit

extension Notification.Name {
    static let togglePlayPause = Notification.Name("togglePlayPause")
}

class WindowManager {
    static var window: NSWindow?
    static var first = true
}

@main
struct MiniPlayerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self)
    var appDelegate

    var body: some Scene {
        Settings {}
    }
}
