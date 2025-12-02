import Foundation

@MainActor
final class AudioQualityDetector {
    private init() {}

    static func trackChanged() {
        print("track change detected")
        Task {
            await AudioQualityMonitor.shared.update()
        }
    }

    static func stream() -> AsyncStream<CMPlayerStats> {
        return AsyncStream { continuation in
            Task {
                let stream = await AudioQualityMonitor.shared.statsStream()
                for await value in stream {
                    continuation.yield(value)
                }
                continuation.finish()
            }
        }
    }
}
