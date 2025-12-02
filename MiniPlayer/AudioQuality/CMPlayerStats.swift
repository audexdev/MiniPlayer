import Foundation
import Sweep
import OSLog

enum AudioCodec: String, Codable, Sendable {
    case atmos
    case lossless
    case aac
}

enum LogType: String, Codable, Sendable {
    case coreaudio
    case music
    case coremedia
}

struct CMPlayerStats: Sendable, Equatable {
    let sampleRate: Double   // Hz
    let bitDepth: Int
    let bitRate: Int
    let codec: AudioCodec
    let date: Date
    let logFrom: LogType
}
