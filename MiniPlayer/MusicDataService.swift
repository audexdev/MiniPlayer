import Foundation
import AppKit
import ScriptingBridge

class MusicDataService: ObservableObject {
    @Published var trackName: String = "Not Playing"
    @Published var artistName: String = ""
    @Published var albumName: String = ""
    @Published var isPlaying: Bool = false
    @Published var albumArt: NSImage? = nil
    @Published var backgroundColor: NSColor = NSColor.windowBackgroundColor
    @Published var volume: Int = 0
    @Published var isDarkBackground: Bool = false
    
    private static let musicBundleID = "com.apple.Music"
    
    private static func makeMusicApp() -> MusicApplication? {
        guard let sb = SBApplication(bundleIdentifier: musicBundleID) else {
            print("Music app proxy failed")
            return nil
        }
        return unsafeBitCast(sb, to: MusicApplication.self)
    }
    
    private let musicApp: MusicApplication? = makeMusicApp()
    private var timer: Timer?
    
    init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSpaceToggle),
            name: .togglePlayPause,
            object: nil
        )
        
        startTimer()
    }
    
    @objc private func handleSpaceToggle() {
        self.toggle()
    }
    
    deinit {
        timer?.invalidate()
    }
    
    func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    func fetchArtwork(title: String, artist: String, album: String, completion: @escaping (NSImage?) -> Void) {
        let query = "\(title) \(artist)"
        
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            completion(nil)
            return
        }

        let urlString = "https://itunes.apple.com/search?term=\(encoded)&entity=song&limit=5"

        URLSession.shared.dataTask(with: URL(string: urlString)!) { data, _, _ in
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let results = json["results"] as? [[String: Any]] else {
                DispatchQueue.main.async { completion(nil) }
                return
            }

            let match = results.first
            
            guard let urlStr = match?["artworkUrl100"] as? String else {
                DispatchQueue.main.async { completion(nil) }
                return
            }

            let hq = urlStr
                .replacingOccurrences(of: "100x100bb", with: "600x600bb")
                .replacingOccurrences(of: "100x100", with: "600x600")

            URLSession.shared.dataTask(with: URL(string: hq)!) { imgData, _, _ in
                let img = imgData.flatMap { NSImage(data: $0) }
                DispatchQueue.main.async { completion(img) }
            }.resume()
            
        }.resume()
    }
    
    func getArtworkViaAppleScript(completion: @escaping (NSImage?) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let scriptSource = """
            tell application "Music"
                if not (exists current track) then return "NO_TRACK"
                try
                    set myArtwork to first artwork of current track
                    set myData to data of myArtwork
                    return myData
                on error
                    return "ERROR"
                end try
            end tell
            """
            
            guard let script = NSAppleScript(source: scriptSource) else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            
            var error: NSDictionary?
            let result = script.executeAndReturnError(&error)
            
            if let err = error {
                print("AppleScript error:", err)
                DispatchQueue.main.async { completion(nil) }
                return
            }
            if result.stringValue == "NO_TRACK" || result.stringValue == "ERROR" {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            
            if let image = NSImage(data: result.data) {
                DispatchQueue.main.async { completion(image) }
            } else {
                DispatchQueue.main.async { completion(nil) }
            }
        }
    }
    
    func getArtwork(title: String, artist: String, album: String, completion: @escaping (NSImage?) -> Void) {
        getArtworkViaAppleScript { img in
            if let img = img {
                completion(img)
                return
            }
        
            // iTunes API for fallback
            self.fetchArtwork(title: title, artist: artist, album: album) { apiImg in
                completion(apiImg)
            }
        }
    }
    
    private var lastKey: String = ""
    
    func refresh() {
        guard let app = musicApp, app.isRunning else { return }
        guard let track = app.currentTrack else { return }

        let title = track.name ?? ""
        let artist = track.artist ?? ""
        let album = track.album ?? ""

        self.trackName = title
        self.artistName = artist
        self.albumName = album
        self.isPlaying = (app.playerState == MusicEPlSPlaying)

        let key = "\(title) | \(artist) | \(album)"
        if key == lastKey { return }
        lastKey = key

#if DEBUG
        print("NEW TRACK:", key)
#endif

        getArtwork(title: title, artist: artist, album: album) { result in
            self.albumArt = result
            
            if let img = result,
               let color = averageColor(from: img) {
                self.backgroundColor = color
                self.isDarkBackground = color.isDark() 
            }
        }
    }
    
    func next() { musicApp?.nextTrack(); refresh() }
    func prev() { musicApp?.previousTrack(); refresh() }
    func toggle() { musicApp?.playpause(); refresh() }
    
    func toggleShuffle() {
        if let app = musicApp {
            app.shuffleEnabled = !app.shuffleEnabled
            refresh()
        }
    }
    
    func onClickRepeat() {
        guard let app = musicApp else { return }

        let mode = app.songRepeat

        if mode == MusicERptOff {
            app.songRepeat = MusicERptAll
        } else if mode == MusicERptAll {
            app.songRepeat = MusicERptOne
        } else {
            app.songRepeat = MusicERptOff
        }

        refresh()
    }
    
    func shuffleState() -> Bool {
        return musicApp?.shuffleEnabled ?? false
    }
    
    func repeatState() -> Int {
        return musicApp?.songRepeat == MusicERptOff ? 0 :
        musicApp?.songRepeat == MusicERptAll ? 1 : 2
    }
    
    func parseTime(_ time: String?) -> Double {
        guard let t = time else { return 0 }
        let parts = t.split(separator: ":").compactMap { Double($0) }
        if parts.count == 2 {
            return parts[0] * 60 + parts[1]
        }
        return 0
    }
    
    func getPlayerPosition() -> (current: Double, duration: Double)? {
        guard let app = musicApp else { return nil }

        let current = app.playerPosition
        let durationString = app.currentTrack?.time
        let duration = parseTime(durationString)

        return (current, duration)
    }
    
    func setPlayerPosition(to seconds: Double) {
        guard let script = NSAppleScript(source:
        """
        tell application "Music"
            set player position to \(seconds)
        end tell
        """
        ) else { return }

        var error: NSDictionary?
        script.executeAndReturnError(&error)
    }
    
    func getVolume() -> Int {
        return musicApp?.soundVolume ?? 100
    }
    
    func setVolume(_ value: Int) {
        musicApp?.soundVolume = value
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
