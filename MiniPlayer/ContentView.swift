import SwiftUI

struct ContentView: View {
    @EnvironmentObject var music: MusicDataService

    @State private var currentTime: Double = 0
    @State private var duration: Double = 1     // avoid divide-by-zero
    
    @State private var isDraggingVolume = false
    @State private var volumeValue: Double = 0

    var body: some View {
        VStack {
            // Album Art
            ZStack {
                if let img = music.albumArt {
                    Image(nsImage: img)
                        .resizable()
                        .frame(width: 300, height: 300)
                        .cornerRadius(12)
                        .shadow(radius: 5)
                        .transition(.opacity)
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.gray.opacity(0.2))
                        Image(systemName: "music.note")
                            .font(.largeTitle)
                            .foregroundColor(.gray)
                    }
                    .frame(width: 300, height: 300)
                    .transition(.opacity)
                }
            }
            .animation(.easeOut(duration: 0.28), value: music.albumArt)
            
            // Track info
            MarqueeText(
                text: music.trackName,
                font: NSFont.systemFont(ofSize: 14, weight: .medium),
                leftFade: 16,
                rightFade: 16,
                startDelay: 1,
                alignment: .center
            )
            
            MarqueeText(
                text: "\(music.artistName) – \(music.albumName)",
                font: NSFont.systemFont(ofSize: 12, weight: .thin),
                leftFade: 16,
                rightFade: 16,
                startDelay: 1,
                alignment: .center
            )
            
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
            
            ZStack {
                if isDraggingVolume {
                    Text("\(Int(volumeValue))")
                        .font(.caption2)
                        .padding(6)
                        .background(.ultraThinMaterial)
                        .cornerRadius(6)
                        .offset(y: -22)
                        .transition(.opacity)
                        .animation(.easeOut(duration: 0.15), value: isDraggingVolume)
                }
                
                HStack {
                    Image(systemName: "speaker.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Slider(
                        value: Binding(
                            get: { volumeValue },
                            set: {
                                volumeValue = $0
                                music.setVolume(Int($0))
                            }
                        ),
                        in: 0...100,
                        onEditingChanged: { editing in
                            isDraggingVolume = editing
                        }
                    )
                    
                    Image(systemName: "speaker.wave.3.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .onAppear {
            volumeValue = Double(music.getVolume())
            
            Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
                if let pos = music.getPlayerPosition() {
                    currentTime = pos.current
                    duration = pos.duration
                }
            }
        }
        .background(Color(nsColor: music.backgroundColor))
        .animation(.easeOut(duration: 0.28), value: music.backgroundColor)
    }

    func formatTime(_ sec: Double) -> String {
        guard sec.isFinite else { return "--:--" }
        let m = Int(sec) / 60
        let s = Int(sec) % 60
        return String(format: "%d:%02d", m, s)
    }
}
