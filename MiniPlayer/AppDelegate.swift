import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldHandleReopen(
        _ sender: NSApplication,
        hasVisibleWindows flag: Bool
    ) -> Bool {
        
        if let win = WindowManager.window {
            win.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
        
        // prevent default func
        if WindowManager.first {
            WindowManager.first = false
            return true
        } else {
            return false
        }
    }
}
