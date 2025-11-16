import SwiftUI

class PlayerUIState: ObservableObject {
    @Published var currentTime: Double = 0
    @Published var duration: Double = 1

    @Published var isDragging: Bool = false
    @Published var dragProgress: Double = 0

    @Published var formattedCurrent: String = "--:--"
    @Published var formattedDuration: String = "--:--"
    
    @Published var isDraggingVolume: Bool = false

    func update(from pos: (current: Double, duration: Double)) {
        if !isDragging {
            currentTime = pos.current
            duration = max(pos.duration, 1)
            formattedCurrent = formatTime(pos.current)
            formattedDuration = formatTime(pos.duration)
        }
    }

    func progress() -> Double {
        if isDragging { return dragProgress }
        return currentTime / duration
    }

    func formatTime(_ sec: Double) -> String {
        guard sec.isFinite else { return "--:--" }
        let m = Int(sec) / 60
        let s = Int(sec) % 60
        return String(format: "%d:%02d", m, s)
    }
}
