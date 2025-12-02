import AppKit

extension NSWindow {
    func overrideMinimizeButton() {
        if let button = standardWindowButton(.miniaturizeButton) {
            button.target = self
            button.action = #selector(customMinimize)
        }
    }

    @objc func customMinimize() {
        #if DEBUG
        print("Custom minimize called")
        #endif
        self.orderOut(nil)
    }
}
