import AppKit
import SwiftUI

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    @MainActor
    lazy var music = MusicDataService()
    let windowState = WindowState()
    let playerUIState = PlayerUIState()
    
    func makeWindowFloat() {
        guard let window = WindowManager.window else { return }

        window.level = NSWindow.Level(rawValue: 5000)
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    }
    
    func setupSpaceKeyControl() {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 49 { // space
                NotificationCenter.default.post(name: .togglePlayPause, object: nil)
                return nil
            }
            return event
        }
    }
    
    func createMainWindow() {
        let contentView = ContentView()
            .environmentObject(self.music)
            .environmentObject(windowState)
            .environmentObject(playerUIState)

        let hosting = NSHostingView(rootView: contentView)
        hosting.wantsLayer = true
        hosting.layer?.cornerRadius = 10
        hosting.layer?.masksToBounds = true

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 550),
            styleMask: [.titled, .fullSizeContentView, .miniaturizable],
            backing: .buffered,
            defer: false
        )

        window.hasShadow = true
        window.contentView = hosting
        window.center()
        window.makeKeyAndOrderFront(nil)
        window.titlebarAppearsTransparent = true
        
        window.overrideMinimizeButton()

        WindowManager.window = window
        
        print("launched")
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        music.bindUIState(playerUIState)
        createMainWindow()
        setupSpaceKeyControl()
        makeWindowFloat()
    }
    
    func applicationShouldHandleReopen(
        _ sender: NSApplication,
        hasVisibleWindows flag: Bool
    ) -> Bool {
        
        if let win = WindowManager.window {
            win.makeKeyAndOrderFront(nil)
        }
        
        music.refresh()
        
        // prevent default func
        if WindowManager.first {
            WindowManager.first = false
            return true
        } else {
            return false
        }
    }
}
