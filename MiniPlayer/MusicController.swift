import Foundation
import AppKit
import ScriptingBridge

struct PlayerSnapshot: @unchecked Sendable, Equatable {
    let trackName: String
    let artistName: String
    let albumName: String
    let isPlaying: Bool
    let albumArt: NSImage?
    let shuffleEnabled: Bool
    let repeatMode: Int
    let volume: Int
    let position: Double
    let duration: Double
}

actor MusicController {
    private static let musicBundleID = "com.apple.Music"

    @MainActor
    private static func createMusicApp() -> MusicApplication? {
        guard let sb = SBApplication(bundleIdentifier: musicBundleID) else {
            print("Music app proxy failed")
            return nil
        }
        return unsafeBitCast(sb, to: MusicApplication.self)
    }

    private var musicApp: MusicApplication?
    private var pollTask: Task<Void, Never>?

    private var latestSnapshot: PlayerSnapshot?
    private var lastPublishedSnapshot: PlayerSnapshot?
    private var continuations: [UUID: AsyncStream<PlayerSnapshot>.Continuation] = [:]

    private var latestArtwork: NSImage?

    // Stable fields to suppress glitches
    private var stableTitle = ""
    private var stableArtist = ""
    private var stableAlbum = ""

    // MARK: - Polling loop

    func start() {
        guard pollTask == nil else { return }
        pollTask = Task { await pollLoop() }
    }

    func stop() {
        pollTask?.cancel()
        pollTask = nil
    }

    private func pollLoop() async {
        while !Task.isCancelled {
            await refreshNow()
            let interval = nextInterval()
            try? await Task.sleep(nanoseconds: interval)
        }
    }

    // MARK: - Core refresh

    func refreshNow() async {
        guard let snapshot = await loadSnapshot() else {
            latestSnapshot = nil
            return
        }

        latestSnapshot = snapshot

        let oldKey = "\(stableTitle)|\(stableArtist)|\(stableAlbum)"

        // stabilize
        let (newTitle, newArtist, newAlbum) = stabilizeFields(
            title: snapshot.trackName,
            artist: snapshot.artistName,
            album: snapshot.albumName
        )

        let newKey = "\(newTitle)|\(newArtist)|\(newAlbum)"

        // detect track change
        if detectTrackChange(oldKey: oldKey, newKey: newKey) {
            Task { @MainActor in
                AudioQualityDetector.trackChanged()
            }
        }

        publishIfChanged(snapshot)
    }

    // MARK: - Stabilization

    private func stabilizeFields(title: String, artist: String, album: String)
        -> (String, String, String)
    {
        let t = title.isEmpty ? stableTitle : title
        let a = artist.isEmpty ? stableArtist : artist
        let al = album.isEmpty ? stableAlbum : album

        stableTitle = t
        stableArtist = a
        stableAlbum = al

        return (t, a, al)
    }

    private func detectTrackChange(oldKey: String, newKey: String) -> Bool {
        return oldKey != newKey
    }

    // MARK: - Publish stream

    func stateStream() -> AsyncStream<PlayerSnapshot> {
        let id = UUID()
        return AsyncStream { continuation in
            continuations[id] = continuation
            if let latest = lastPublishedSnapshot ?? latestSnapshot {
                continuation.yield(latest)
            }
            continuation.onTermination = { @Sendable _ in
                Task { await self.removeContinuation(id: id) }
            }
        }
    }

    private func removeContinuation(id: UUID) {
        continuations[id] = nil
    }

    private func broadcast(_ snapshot: PlayerSnapshot) {
        continuations.values.forEach { $0.yield(snapshot) }
    }

    private func publishIfChanged(_ snapshot: PlayerSnapshot) {
        if lastPublishedSnapshot != snapshot {
            lastPublishedSnapshot = snapshot
            broadcast(snapshot)
        }
    }

    // MARK: - Snapshot load

    private func loadSnapshot() async -> PlayerSnapshot? {
        guard let app = await ensureMusicApp() else { return nil }
        guard await MainActor.run(body: { app.isRunning }) else { return nil }
        guard let inputs = await readSnapshotInputs(app: app) else { return nil }

        let key = "\(inputs.title)|\(inputs.artist)|\(inputs.album)"
        var artwork = latestArtwork

        if key != "\(stableTitle)|\(stableArtist)|\(stableAlbum)" {
            async let artAsync: NSImage? = getArtwork(
                title: inputs.title,
                artist: inputs.artist,
                album: inputs.album
            )
            artwork = await artAsync
            latestArtwork = artwork
        }

        return PlayerSnapshot(
            trackName: inputs.title,
            artistName: inputs.artist,
            albumName: inputs.album,
            isPlaying: inputs.isPlaying,
            albumArt: artwork,
            shuffleEnabled: inputs.shuffleEnabled,
            repeatMode: inputs.repeatMode,
            volume: inputs.volume,
            position: inputs.position,
            duration: inputs.duration
        )
    }

    private func ensureMusicApp() async -> MusicApplication? {
        if let app = musicApp { return app }
        let app = await MainActor.run { Self.createMusicApp() }
        musicApp = app
        return app
    }

    // MARK: - Read inputs

    private struct SnapshotInputs {
        let title: String
        let artist: String
        let album: String
        let position: Double
        let duration: Double
        let shuffleEnabled: Bool
        let repeatMode: Int
        let volume: Int
        let isPlaying: Bool
    }

    private func readSnapshotInputs(app: MusicApplication) async -> SnapshotInputs? {
        await MainActor.run {
            guard let track = app.currentTrack else { return nil }

            let title = track.name ?? ""
            let artist = track.artist ?? ""
            let album = track.album ?? ""

            let position = app.playerPosition
            let duration = Self.parseTime(track.time)
            let shuffleEnabled = app.shuffleEnabled
            let repeatMode = Self.mapRepeatMode(app.songRepeat)
            let volume = app.soundVolume
            let isPlaying = (app.playerState == MusicEPlSPlaying)

            return SnapshotInputs(
                title: title,
                artist: artist,
                album: album,
                position: position,
                duration: duration,
                shuffleEnabled: shuffleEnabled,
                repeatMode: repeatMode,
                volume: volume,
                isPlaying: isPlaying
            )
        }
    }

    private static func parseTime(_ time: String?) -> Double {
        guard let t = time else { return 0 }
        let parts = t.split(separator: ":").compactMap { Double($0) }
        if parts.count == 2 {
            return parts[0] * 60 + parts[1]
        }
        return 0
    }

    private static func mapRepeatMode(_ mode: MusicERpt) -> Int {
        if mode == MusicERptOff { return 0 }
        if mode == MusicERptAll { return 1 }
        return 2
    }

    // MARK: - Artwork

    private func fetchArtwork(title: String, artist: String, album: String) async -> NSImage? {
        let query = "\(title) \(artist)"
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return nil
        }
        let urlString = "https://itunes.apple.com/search?term=\(encoded)&entity=song&limit=5"
        guard let url = URL(string: urlString) else { return nil }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                let results = json["results"] as? [[String: Any]],
                let match = results.first,
                let urlStr = match["artworkUrl100"] as? String
            else {
                return nil
            }

            let hq = urlStr
                .replacingOccurrences(of: "100x100bb", with: "600x600bb")
                .replacingOccurrences(of: "100x100", with: "600x600")

            guard let hqURL = URL(string: hq) else { return nil }
            let (imgData, _) = try await URLSession.shared.data(from: hqURL)
            return NSImage(data: imgData)
        } catch {
            return nil
        }
    }

    private func getArtworkViaAppleScript() async -> NSImage? {
        await MainActor.run {
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

            guard let script = NSAppleScript(source: scriptSource) else { return nil }
            var error: NSDictionary?
            let result = script.executeAndReturnError(&error)

            if error != nil { return nil }
            if result.stringValue == "NO_TRACK" || result.stringValue == "ERROR" {
                return nil
            }

            return NSImage(data: result.data)
        }
    }

    private func getArtwork(title: String, artist: String, album: String) async -> NSImage? {
        if let img = await getArtworkViaAppleScript() {
            return img
        }
        return await fetchArtwork(title: title, artist: artist, album: album)
    }

    // MARK: - Control actions

    func nextTrack() async {
        guard let app = await ensureMusicApp() else { return }
        await MainActor.run { app.nextTrack() }
        await refreshNow()
    }

    func previousTrack() async {
        guard let app = await ensureMusicApp() else { return }
        await MainActor.run { app.previousTrack() }
        await refreshNow()
    }

    func togglePlayPause() async {
        guard let app = await ensureMusicApp() else { return }
        await MainActor.run { app.playpause() }
        await refreshNow()
    }

    func toggleShuffle() async {
        guard let app = await ensureMusicApp() else { return }
        await MainActor.run { app.shuffleEnabled.toggle() }
        await refreshNow()
    }

    func cycleRepeatMode() async {
        guard let app = await ensureMusicApp() else { return }
        await MainActor.run {
            let mode = app.songRepeat
            if mode == MusicERptOff {
                app.songRepeat = MusicERptAll
            } else if mode == MusicERptAll {
                app.songRepeat = MusicERptOne
            } else {
                app.songRepeat = MusicERptOff
            }
        }
        await refreshNow()
    }

    func setPlayerPosition(to seconds: Double) async {
        guard let _ = await ensureMusicApp() else { return }
        await MainActor.run {
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
        await refreshNow()
    }

    func setVolume(_ value: Int) async {
        guard let app = await ensureMusicApp() else { return }
        await MainActor.run { app.soundVolume = value }
        await refreshNow()
    }

    private func nextInterval() -> UInt64 {
        guard let snapshot = latestSnapshot else {
            return 5_000_000_000 // 0.2 Hz
        }

        if snapshot.isPlaying {
            return 1_000_000_000 // 1 Hz
        } else {
            return 2_000_000_000 // 0.5 Hz
        }
    }
}
