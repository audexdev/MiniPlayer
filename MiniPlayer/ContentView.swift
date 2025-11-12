import SwiftUI

struct ContentView: View {
    @StateObject var music = MusicDataService()

    @State private var currentTime: Double = 0
    @State private var duration: Double = 1     // avoid divide-by-zero

    var body: some View {
        VStack(spacing: 12) {
            // Album Art
            if let img = music.albumArt {
                Image(nsImage: img)
                    .resizable()
                    .frame(width: 250, height: 250)
                    .cornerRadius(12)
                    .shadow(radius: 5)
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 250, height: 250)
                    Image(systemName: "music.note")
                        .font(.largeTitle)
                        .foregroundColor(.gray)
                }
            }

            // Track info
            Text(music.trackName)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
            Text("\(music.artistName) - \(music.albumName)")
                .font(.system(size: 12, weight: .regular, design: .rounded))
                .foregroundColor(.secondary)

            VStack {
                Slider(value: $currentTime, in: 0...duration, onEditingChanged: { editing in
                    if !editing {
                        music.setPlayerPosition(to: currentTime)
                    }
                })

                HStack {
                    Text(formatTime(currentTime))
                    Spacer()
                    Text(formatTime(duration))
                }
                .font(.caption2)
                .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)

            // Controls
            HStack {
                Button {
                    music.toggleShuffle()
                } label: {
                    Image(systemName: "shuffle")
                    .foregroundColor(music.shuffleState() ? .red : .gray)
                    .font(.system(size: 16))
                }
                Button("⏮") { music.prev() }
                Button(music.isPlaying ? "⏸" : "▶") { music.toggle() }
                Button("⏭") { music.next() }
                Button {
                    music.onClickRepeat()
                } label: {
                    Image(systemName:
                            music.repeatState() == 2 /* repeat one */ ? "repeat.1" : "repeat"
                    )
                    .foregroundColor(music.repeatState() == 0 /* repeat off */ ? .gray : .red)
                    .font(.system(size: 16))
                }
            }
            .buttonStyle(HoverButtonStyle())
            .font(.largeTitle)
        }
        .padding()
        .onAppear {
            Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
                if let pos = music.getPlayerPosition() {
                    currentTime = pos.current
                    duration = pos.duration
                }
            }
        }
        .cornerRadius(24)
        .shadow(radius: 1)
    }

    func formatTime(_ sec: Double) -> String {
        guard sec.isFinite else { return "--:--" }
        let m = Int(sec) / 60
        let s = Int(sec) % 60
        return String(format: "%d:%02d", m, s)
    }
}
