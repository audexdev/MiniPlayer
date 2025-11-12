import SwiftUI
import AppKit

extension Notification.Name {
    static let togglePlayPause = Notification.Name("togglePlayPause")
}

@main
struct MiniPlayerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    makeWindowFloat()
                    enableSpaceKeyControl()
                }
        }
    }

    func makeWindowFloat() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if let window = NSApplication.shared.windows.first {
                window.level = NSWindow.Level(rawValue: 5000)
                window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
                //window.titlebarAppearsTransparent = true
                window.isMovableByWindowBackground = true
                //window.styleMask.remove(.titled)
                window.styleMask.remove(.resizable)
                window.standardWindowButton(.closeButton)?.isEnabled = false
            }
        }
    }
    
    func enableSpaceKeyControl() {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 49 {
                NotificationCenter.default.post(name: .togglePlayPause, object: nil)
                return nil
            }
            return event
        }
    }
}
