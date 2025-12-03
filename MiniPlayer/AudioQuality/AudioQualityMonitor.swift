import Foundation
import OSLog

actor AudioQualityMonitor {

    static let shared = AudioQualityMonitor()

    private var sessionTask: Task<Void, Never>?
    private var latest: CMPlayerStats?
    private var continuations: [UUID: AsyncStream<CMPlayerStats>.Continuation] = [:]
    private var trackToken: UUID = UUID()
    private var trackStart: Date = .distantPast
    private var seenSources = Set<LogType>()
    private var lastScanDate: Date?

    private init() {}

    func update() {
        sessionTask?.cancel()
        trackToken = UUID()
        trackStart = Date()
        latest = nil
        seenSources = []
        lastScanDate = nil
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

    private func removeCont(id: UUID) {
        continuations[id] = nil
    }

    private func broadcast(_ stats: CMPlayerStats) {
        for c in continuations.values {
            c.yield(stats)
        }
    }

    private func runSession(track: UUID) async {
        let store = try? OSLogStore.local()
        guard let store else { return }

        let timeout: TimeInterval = 4
        let start = Date()

        while Date().timeIntervalSince(start) < timeout {
            if Task.isCancelled || track != trackToken { return }

            if let stats = await scanOnce(store: store) {
                latest = stats
                broadcast(stats)

                if stats.logFrom == .coreaudio {
                    return
                }

                if seenSources.contains(.coremedia) &&
                    seenSources.contains(.music) {
                    return
                }
            }

            try? await Task.sleep(for: .milliseconds(100))
        }
    }

    private func scanOnce(store: OSLogStore) async -> CMPlayerStats? {
        return autoreleasepool {
            do {
                let fromDate = lastScanDate ?? trackStart.addingTimeInterval(-3)
                let pos = store.position(date: fromDate)
                let entries = try store.getEntries(with: [], at: pos)

                var merged: CMPlayerStats?
                var maxDate: Date?

                for case let log as OSLogEntryLog in entries {
                    guard let stats = parse(log) else { continue }

                    if stats.date < trackStart.addingTimeInterval(-3) {
                        continue
                    }

                    let source = stats.logFrom

                    if self.seenSources.contains(source) {
                        continue
                    }

                    merged = merge(current: merged, candidate: stats)
                    self.seenSources.insert(source)

                    if maxDate == nil || stats.date > maxDate! {
                        maxDate = stats.date
                    }
                }

                if let maxDate {
                    self.lastScanDate = maxDate
                }

                return merged
            } catch {
                print("[AUDIO] scan error:", error)
                return nil
            }
        }
    }

    private func parse(_ log: OSLogEntryLog) -> CMPlayerStats? {
        let msg = log.composedMessage
        let subsystem = log.subsystem
        let date = log.date

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

        if subsystem == "com.apple.Music" {
            var sr: Double?
            var bd: Int?
            var bitrate: Int?
            var atmos = false

            if let srStr = msg.firstSubstring(between: "asbdSampleRate = ", and: " kHz"),
               let val = Double(srStr) {
                sr = val * 1000
            }

            if let bdStr = msg.firstSubstring(between: "sdBitDepth = ", and: " bit"),
               let val = Int(bdStr) {
                bd = val
            } else if let brStr = msg.firstSubstring(between: "sdBitRate = ", and: " kbps"),
                      let val = Int(brStr) {
                bitrate = val
            }

            if let format = msg.firstSubstring(between: "asbdFormatID = ", and: ", sdFormatID"),
               format == "qc+3" {
                atmos = true
            }

            if msg.contains("Dolby Atmos") ||
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

        if subsystem == "com.apple.coremedia",
           msg.contains("Creating AudioQueue"),
           let srStr = msg.firstSubstring(between: "sampleRate:", and: .end),
           let sr = Double(srStr) {
            let fmt = msg.firstSubstring(between: "format:'", and: "'")
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

    private func merge(current: CMPlayerStats?, candidate: CMPlayerStats) -> CMPlayerStats {
        guard var best = current else { return normalize(candidate) }
        let cand = normalize(candidate)

        let withinAtmosWindow = cand.codec == .atmos && cand.date.timeIntervalSince(trackStart) < 1.0
        let effectiveCodec: AudioCodec = withinAtmosWindow ? cand.codec : (cand.codec == .atmos ? best.codec : cand.codec)

        switch cand.logFrom {
        case .coreaudio:
            best = CMPlayerStats(
                sampleRate: cand.sampleRate,
                bitDepth: cand.bitDepth,
                bitRate: cand.bitRate,
                codec: effectiveCodec == .atmos ? .atmos : .lossless,
                date: cand.date,
                logFrom: cand.logFrom
            )
        case .coremedia:
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
                codec = .lossless
            }
        }

        if stats.logFrom == .coremedia {
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
