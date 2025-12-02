import Foundation
import AppKit

@MainActor
final class MusicDataService: ObservableObject {
    @Published var trackName: String = "Not Playing"
    @Published var artistName: String = ""
    @Published var albumName: String = ""
    @Published var isPlaying: Bool = false
    @Published var albumArt: NSImage? = nil
    @Published var backgroundColor: NSColor = NSColor.windowBackgroundColor
    @Published var volume: Int = 0
    @Published var isDarkBackground: Bool = false
    @Published var qualityLabel: String = ""

    private let controller = MusicController()
    private let artworkProcessor = ArtworkProcessor.shared
    private var stateTask: Task<Void, Never>?
    private var qualityTask: Task<Void, Never>?
    private weak var playerUIState: PlayerUIState?
    
    init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSpaceToggle),
            name: .togglePlayPause,
            object: nil
        )
        
        Task {
            await controller.start()
            startStateStream()
            startQualityLoop()
        }
    }
    
    @objc private func handleSpaceToggle() {
        toggle()
    }
    
    deinit {
        stateTask?.cancel()
        qualityTask?.cancel()
    }
    
    func bindUIState(_ uiState: PlayerUIState) {
        self.playerUIState = uiState
    }

    private func startStateStream() {
        stateTask = Task { [weak self] in
            guard let self else { return }
            let stream = await controller.stateStream()
            for await snapshot in stream {
                await MainActor.run {
                    self.apply(snapshot)
                }
            }
        }
    }
    
    private func startQualityLoop() {
        qualityTask = Task { [weak self] in
            guard let self else { return }
            for await q in AudioQualityDetector.stream() {
                let khz = q.sampleRate / 1000.0
                let srText = String(format: "%.1f kHz", khz)
                let bd = q.bitDepth
                let label: String
                if q.codec == .atmos || q.bitRate == 768 {
                    label = "Dolby Atmos"
                } else if q.codec == .lossless {
                    label = "\(bd)-bit / \(srText)"
                } else if q.bitRate != -1 {
                    label = "AAC \(q.bitRate) kbps"
                } else {
                    label = "AAC"
                }
                await MainActor.run {
                    self.qualityLabel = label
                    print("AudioQuality update:", label)
                    print("log from:", q.logFrom)
                    print("Current music:", self.trackName)
                }
            }
        }
    }
    
    private func apply(_ snapshot: PlayerSnapshot) {
        trackName = snapshot.trackName
        artistName = snapshot.artistName
        albumName = snapshot.albumName
        isPlaying = snapshot.isPlaying
        shuffleCache = snapshot.shuffleEnabled
        repeatCache = snapshot.repeatMode
        volume = snapshot.volume
        playerUIState?.update(from: (snapshot.position, snapshot.duration))

        let key = "\(snapshot.trackName) | \(snapshot.artistName) | \(snapshot.albumName)"
        artworkProcessor.process(image: snapshot.albumArt, key: key) { [weak self] img, color, isDark in
            guard let self else { return }
            self.albumArt = img
            if let color = color {
                self.backgroundColor = color
                self.isDarkBackground = isDark
            }
        }
    }
    
    func refresh() {
        Task { await controller.refreshNow() }
    }
    
    func next() { Task { await controller.nextTrack() } }
    func prev() { Task { await controller.previousTrack() } }
    func toggle() { Task { await controller.togglePlayPause() } }
    
    func toggleShuffle() {
        Task { await controller.toggleShuffle() }
    }
    
    func onClickRepeat() {
        Task { await controller.cycleRepeatMode() }
    }
    
    private var shuffleCache: Bool = false
    func shuffleState() -> Bool {
        return shuffleCache
    }
    
    private var repeatCache: Int = 0
    func repeatState() -> Int {
        return repeatCache
    }
    
    func getPlayerPosition() -> (current: Double, duration: Double)? {
        return playerUIState.map { ($0.currentTime, $0.duration) }
    }
    
    func setPlayerPosition(to seconds: Double) {
        Task { await controller.setPlayerPosition(to: seconds) }
    }
    
    func getVolume() -> Int {
        return volume
    }
    
    func setVolume(_ value: Int) {
        volume = value
        Task { await controller.setVolume(value) }
    }
    
    func setWindowSize(compact: Bool) {
        guard
            let window = NSApp.windows.first,
            let screen = window.screen ?? NSScreen.main
        else { return }

        let oldFrame = window.frame

        let newSize = compact
            ? NSSize(width: 332, height: 160)
            : NSSize(width: 332, height: 510)

        let screenFrame = screen.visibleFrame

        let screenCenterX = screenFrame.midX
        let screenCenterY = screenFrame.midY

        let isLeft = oldFrame.minX < screenCenterX
        let isBottom = oldFrame.minY < screenCenterY

        let dx = newSize.width  - oldFrame.size.width
        let dy = newSize.height - oldFrame.size.height

        var origin = oldFrame.origin

        // horizontal anchor
        if !isLeft {  // right side
            origin.x -= dx
        }

        // vertical anchor
        if !isBottom { // top side
            origin.y -= dy
        }

        let newFrame = NSRect(origin: origin, size: newSize)
        window.setFrame(newFrame, display: true, animate: true)
    }
    
    func setWindowOpacity(compact: Bool) {
        guard let window = NSApp.windows.first else { return }

        if compact {
            window.isOpaque = false
            window.backgroundColor = NSColor.clear.withAlphaComponent(0.0)
        } else {
            window.isOpaque = false
            window.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(1.0)
        }
    }
}
