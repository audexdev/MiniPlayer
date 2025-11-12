import Foundation
import AppKit
import ScriptingBridge

struct ArtworkResult {
    let url: URL
    let image: NSImage?
}

class MusicDataService: ObservableObject {
    @Published var trackName: String = "Not Playing"
    @Published var artistName: String = ""
    @Published var albumName: String = ""
    @Published var isPlaying: Bool = false
    @Published var albumArt: NSImage? = nil
    
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
                  let results = json["results"] as? [[String: Any]]
            else {
                DispatchQueue.main.async { completion(nil) }
                return
            }

            let normalizedArtist = artist.lowercased()
            let normalizedAlbum = album.lowercased()

            let match =
                results.first(where: { ($0["artistName"] as? String)?.lowercased() == normalizedArtist &&
                                       ($0["collectionName"] as? String)?.lowercased() == normalizedAlbum })
            ??  results.first(where: { ($0["artistName"] as? String)?.lowercased() == normalizedArtist })
            ??  results.first

            guard let urlStr = match?["artworkUrl100"] as? String else {
                DispatchQueue.main.async { completion(nil) }
                return
            }

            // HQ artwork URL (600x600 or better)
            let hq = urlStr
                .replacingOccurrences(of: "100x100bb", with: "600x600bb")
                .replacingOccurrences(of: "100x100", with: "600x600")

            URLSession.shared.dataTask(with: URL(string: hq)!) { imgData, _, _ in
                let img = imgData.flatMap { NSImage(data: $0) }
                DispatchQueue.main.async { completion(img) }
            }
            .resume()

        }
        .resume()
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
        print("NEW TRACK: \(key)")
        #endif
        
        fetchArtwork(title: title, artist: artist, album: album) { result in
            DispatchQueue.main.async {
                self.albumArt = result
            }
        }
    }
    
    func next() { musicApp?.nextTrack(); refresh() }
    func prev() { musicApp?.previousTrack(); refresh() }
    func toggle() { musicApp?.playpause(); refresh() }
    
    func toggleShuffle() {
        if let app = musicApp {
            app.shuffleEnabled = !(app.shuffleEnabled ?? false)
            refresh()
        }
    }
    
    func onClickRepeat() {
        guard let app = musicApp else { return }

        let mode = app.songRepeat ?? MusicERptOff

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
        let durationString = app.currentTrack?.time  // 例: "3:49"
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
}
