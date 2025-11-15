import AppKit

class WindowResizer {    
    static func toggleResizable() {
        guard let window = NSApplication.shared.windows.first else { return }

        if window.styleMask.contains(.resizable) {
            window.styleMask.remove(.resizable)
        } else {
            window.styleMask.insert(.resizable)
        }
    }

    static func isResizable() -> Bool {
        guard let window = NSApplication.shared.windows.first else { return false }
        return window.styleMask.contains(.resizable)
    }
}
