import Foundation
import OSLog

actor AudioQualityMonitor {

    static let shared = AudioQualityMonitor()

    private var sessionTask: Task<Void, Never>?
    private var latest: CMPlayerStats?
    private var continuations: [UUID: AsyncStream<CMPlayerStats>.Continuation] = [:]
    private var trackToken: UUID = UUID()
    private var trackStart: Date = .distantPast
    private var store: OSLogStore?
    private var lastPosition: OSLogPosition?

    private init() {}

    // MARK: - PUBLIC
    func update() {
        sessionTask?.cancel()
        trackToken = UUID()
        trackStart = Date()
        lastPosition = nil
        latest = nil
        sessionTask = Task { await runSession(track: trackToken) }
    }

    func statsStream() -> AsyncStream<CMPlayerStats> {
        let id = UUID()
        return AsyncStream { continuation in
            continuations[id] = continuation
            if let latest { continuation.yield(latest) }

            continuation.onTermination = { @Sendable _ in
                Task { await self.removeCont(id: id) }
            }
        }
    }

    // MARK: - PRIVATE CORE

    private func removeCont(id: UUID) {
        continuations[id] = nil
    }

    private func broadcast(_ stats: CMPlayerStats) {
        for c in continuations.values {
            c.yield(stats)
        }
    }

    private func runSession(track: UUID) async {
        let store: OSLogStore
        do {
            store = try OSLogStore.local()
        } catch {
            print("[AUDIO] scan error:", error)
            return
        }

        let start = Date()
        let duration: TimeInterval = 1.0

        while Date().timeIntervalSince(start) < duration {
            if Task.isCancelled || track != trackToken { return }

            if let stats = await scanOnce(store: store) {
                latest = stats
                broadcast(stats)
            }

            try? await Task.sleep(nanoseconds: 50_000_000)
        }
    }

    private func scanOnce(store: OSLogStore) async -> CMPlayerStats? {
        do {
            let pos = try store.position(timeIntervalSinceEnd: -1.5)
            let entries = try store.getEntries(with: [], at: pos)

            var merged: CMPlayerStats?

            for case let log as OSLogEntryLog in entries {
                if let stats = parse(log) {
                    merged = merge(current: merged, candidate: stats)
                }
            }

            return merged
        } catch {
            print("[AUDIO] scan error:", error)
            return nil
        }
    }

    // MARK: - PARSE LOG

    private func parse(_ log: OSLogEntryLog) -> CMPlayerStats? {
        let msg = log.composedMessage
        let subsystem = log.subsystem
        let date = log.date

        // ------ CORE AUDIO (ALAC / Lossless) ------
        if subsystem == "com.apple.coreaudio",
           msg.contains("ACAppleLosslessDecoder"),
           msg.contains("Input format:") {

            let sr = msg.firstSubstring(between: "ch, ", and: " Hz")
                .flatMap { Double(String($0)) }

            let bd = msg.firstSubstring(between: "from ", and: "-bit source")
                .flatMap { Int(String($0)) }

            if let sr, let bd {
                return CMPlayerStats(
                    sampleRate: sr,
                    bitDepth: bd,
                    bitRate: -1,
                    codec: .lossless,
                    date: date,
                    logFrom: .coreaudio
                )
            }
        }

        // ------ MUSIC APP Logs ------
        if subsystem == "com.apple.Music" {
            var sr: Double?
            var bd: Int?
            var bitrate: Int?
            var atmos = false

            // inaccurate sr
            if let srStr = msg.firstSubstring(between: "asbdSampleRate = ", and: " kHz"),
               let val = Double(srStr) {
                sr = val * 1000
            }

            if let bdStr = msg.firstSubstring(between: "sdBitDepth = ", and: " bit"),
               let val = Int(bdStr) {
                bd = val
            }
            else if let brStr = msg.firstSubstring(between: "sdBitRate = ", and: " kbps"),
                    let val = Int(brStr) {
                // aac or atmos
                bitrate = val
            }
            
            if let format = msg.firstSubstring(between: "asbdFormatID = ", and: ", sdFormatID"), format == "qc+3" {
                atmos = true
            }

            if msg.contains("Dolby Atmos") ||
                msg.contains("is rendering spatial audio") ||
                msg.contains("is Atmos") ||
                msg.contains("is binaural") ||
                msg.contains("original is Atmos") ||
                msg.contains("play> select> select CMPlayer for spatial") ||
                msg.contains("spatialAudio = enabled") {
                atmos = true
            }

            if let sr, let bd {
                return CMPlayerStats(
                    sampleRate: sr,
                    bitDepth: bd,
                    bitRate: bitrate ?? -1,
                    codec: atmos ? .atmos : bitrate != nil ? .aac : .lossless,
                    date: date,
                    logFrom: .music
                )
            }
        }

        // ------ CORE MEDIA fallback ------
            if subsystem == "com.apple.coremedia",
           msg.contains("Creating AudioQueue"),
           let srStr = msg.firstSubstring(between: "sampleRate:", and: .end),
           let sr = Double(srStr) {
            let fmt = msg.firstSubstring(between: "format:'", and: "'")
            
            /*print("coremedia")
            if msg.contains("dolby") ||
                msg.contains("atmos") ||
                msg.contains("spatial") ||
                msg.contains("channel") ||
                msg.contains("format") {
                print("dolby atmos:", msg)
            }*/
            
            let bd = sr == 44100 ? 16 : 24
            
            switch fmt {
            case "qc+3":
                return CMPlayerStats(sampleRate: sr, bitDepth: bd, bitRate: 768, codec: .atmos, date: date, logFrom: .coremedia)
                
            case "qlac":
                return CMPlayerStats(sampleRate: sr, bitDepth: bd, bitRate: -1, codec: .lossless, date: date, logFrom: .coremedia)
                
            case "qaac":
                return CMPlayerStats(sampleRate: sr, bitDepth: bd, bitRate: 256, codec: .aac, date: date, logFrom: .coremedia)
                
            default:
                return CMPlayerStats(
                    sampleRate: sr,
                    bitDepth: bd,
                    bitRate: -1,
                    codec: .lossless,
                    date: date,
                    logFrom: .coremedia
                )
            }
        }

        return nil
    }

    // MARK: - Merge logic

    private func merge(current: CMPlayerStats?, candidate: CMPlayerStats) -> CMPlayerStats {
        guard var best = current else { return normalize(candidate) }
        let cand = normalize(candidate)

        // Per-track atmos gating: only allow Atmos flags within 1s of track change
        let withinAtmosWindow = cand.codec == .atmos && Date().timeIntervalSince(trackStart) < 1.0
        let effectiveCodec: AudioCodec = withinAtmosWindow ? cand.codec : (cand.codec == .atmos ? best.codec : cand.codec)

        switch cand.logFrom {
        case .coreaudio:
            // CoreAudio is authoritative
            best = CMPlayerStats(
                sampleRate: cand.sampleRate,
                bitDepth: cand.bitDepth,
                bitRate: cand.bitRate,
                codec: effectiveCodec == .atmos ? .atmos : .lossless,
                date: cand.date,
                logFrom: cand.logFrom
            )
        case .coremedia:
            // CoreMedia provides sr/codec/bitrate; keep bitDepth from music if available
            let resolvedBitDepth = best.logFrom == .music && best.bitDepth != -1 ? best.bitDepth : cand.bitDepth
            best = CMPlayerStats(
                sampleRate: cand.sampleRate,
                bitDepth: resolvedBitDepth,
                bitRate: cand.bitRate,
                codec: effectiveCodec,
                date: cand.date,
                logFrom: cand.logFrom
            )
        case .music:
            // Music only overrides bitDepth; do not override sr if missing/invalid
            let sr = cand.sampleRate > 0 ? cand.sampleRate : best.sampleRate
            let bitDepth = cand.bitDepth != -1 ? cand.bitDepth : best.bitDepth
            let bitRate = cand.bitRate != -1 ? cand.bitRate : best.bitRate
            let codec = effectiveCodec == .atmos ? .atmos : (bitRate != -1 ? .aac : best.codec)
            best = CMPlayerStats(
                sampleRate: sr,
                bitDepth: bitDepth,
                bitRate: bitRate,
                codec: codec,
                date: cand.date,
                logFrom: best.logFrom
            )
        }

        return best
    }

    private func normalize(_ stats: CMPlayerStats) -> CMPlayerStats {
        // Music-only logs missing sr: fallback for codec/bitDepth/sr
        var sr = stats.sampleRate
        var bd = stats.bitDepth
        var codec = stats.codec
        var bitRate = stats.bitRate

        if stats.logFrom == .music {
            if sr == 0 { sr = -1 }
            if bd == 0 { bd = -1 }
            if bitRate != -1 { codec = .aac }
            if codec == .atmos { bitRate = max(bitRate, 768) }
            if codec == .lossless && sr == -1 && bitRate == -1 {
                codec = .lossless // unknown SR lossless
            }
        }

        if stats.logFrom == .coremedia {
            // If qlac at 44.1, allow 24bit later from music
            if bd == 0 { bd = -1 }
        }

        return CMPlayerStats(
            sampleRate: sr,
            bitDepth: bd,
            bitRate: bitRate,
            codec: codec,
            date: stats.date,
            logFrom: stats.logFrom
        )
    }
}
