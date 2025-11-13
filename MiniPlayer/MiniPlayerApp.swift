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
        WindowGroup {
            ContentView()
                .onAppear {
                    makeWindowFloat()
                    enableSpaceKeyControl()
                }
        }
        .commands {
                    CommandGroup(after: .windowSize) {
                        Divider()
                        Toggle("Resizable Window", isOn: Binding(
                            get: { WindowResizer.isResizable() },
                            set: { _ in WindowResizer.toggleResizable() }
                        ))
                        .keyboardShortcut("R", modifiers: [.command, .shift])
                    }
                }
    }

    func makeWindowFloat() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if let window = NSApplication.shared.windows.first {
                window.level = NSWindow.Level(rawValue: 5000)
                window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
                window.isMovableByWindowBackground = true
                //window.styleMask.remove(.titled)
                window.styleMask.remove(.resizable)
                window.standardWindowButton(.closeButton)?.isEnabled = false
                
                window.styleMask.insert(.fullSizeContentView)
                window.titleVisibility = .hidden
                window.titlebarAppearsTransparent = true
                window.titlebarSeparatorStyle = .none
                
                WindowManager.window = window
                
                window.overrideMinimizeButton()
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
