import OSLog

enum EntryType: String {
    case music = "com.apple.Music"
    case coreAudio = "com.apple.coreaudio"
    case coreMedia = "com.apple.coremedia"

    var subsystem: String { rawValue }
}

struct SimpleConsole {
    let date: Date
    let message: String
}
