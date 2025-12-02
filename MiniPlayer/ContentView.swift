import SwiftUI

struct ContentView: View {
    @EnvironmentObject var music: MusicDataService
    @EnvironmentObject var windowState: WindowState
    @EnvironmentObject var ui: PlayerUIState

    @State private var volumeValue: Double = 0
    @State private var volumeTask: Task<Void, Never>?

    var body: some View {
        Group {
            if windowState.isCompact {
                CompactMiniPlayerView()
            } else {
                fullMiniPlayerView
            }
        }
        .onAppear {
            volumeValue = Double(music.getVolume())
        }
        .onReceive(music.$volume) { newValue in
            if !ui.isDraggingVolume {
                volumeValue = Double(newValue)
            }
        }
        .background(Color(nsColor: music.backgroundColor))
        .animation(.easeOut(duration: 0.28), value: music.backgroundColor)
    }

    private var fullMiniPlayerView: some View {
        VStack {
            // Artwork
            ZStack {
                if let img = music.albumArt {
                    Image(nsImage: img)
                        .resizable()
                        .frame(width: 300, height: 300)
                        .cornerRadius(12)
                        .shadow(radius: 5)
                        .onTapGesture { toggleCompact() }
                        .transition(.opacity)
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12).fill(Color.gray.opacity(0.2))
                        Image(systemName: "music.note")
                            .font(.largeTitle)
                            .foregroundColor(.gray)
                    }
                    .frame(width: 300, height: 300)
                    .onTapGesture { toggleCompact() }
                }
            }

            MarqueeText(
                text: music.trackName,
                font: NSFont.systemFont(ofSize: 14, weight: .medium),
                leftFade: 16, rightFade: 16, startDelay: 1, alignment: .center
            )

            MarqueeText(
                text: "\(music.artistName) – \(music.albumName)",
                font: NSFont.systemFont(ofSize: 12, weight: .thin),
                leftFade: 16, rightFade: 16, startDelay: 1, alignment: .center
            )

            // Progress bar
            VStack {
                Slider(
                    value: Binding(
                        get: { ui.currentTime },
                        set: { ui.currentTime = $0 }
                    ),
                    in: 0...ui.duration,
                    onEditingChanged: { editing in
                        if !editing {
                            music.setPlayerPosition(to: ui.currentTime)
                        }
                    }
                )

                HStack {
                    Text(ui.formattedCurrent)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    HStack(spacing: 6) {
                        if music.codec == .atmos {
                            Image("Dolby_Atmos")
                                .resizable()
                                .interpolation(.high)
                                .antialiased(false)
                                .renderingMode(.template)
                                .foregroundColor(.secondary)
                                .frame(width: 100, height: 15.625)
                                .fixedSize()
                        } else if music.codec == .lossless {
                            Image("Lossless")
                                .resizable()
                                .interpolation(.none)
                                .antialiased(false)
                                .renderingMode(.template)
                                .foregroundColor(.secondary)
                                .frame(width: 10, height: 10)
                                .fixedSize()
                        }

                        if music.codec != .atmos {
                            Text(music.qualityLabel)
                                .font(.system(size: 13, weight: .light))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                                .truncationMode(.tail)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .layoutPriority(10)
                    .frame(width: 170)

                    Text(ui.formattedDuration)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }

            // Controls
            playerControls
                .padding(.bottom, 8)

            // Volume
            volumeSlider
        }
        .padding()
    }

    private var playerControls: some View {
        HStack(spacing: 16) {
            Button { music.toggleShuffle() } label: {
                Image(systemName: "shuffle")
                    .foregroundColor(music.shuffleState() ? .red : .gray)
            }
            Button(action: music.prev) {
                Image(systemName: "backward.fill")
            }
            Button(action: music.toggle) {
                Image(systemName: music.isPlaying ? "pause.fill" : "play.fill")
            }
            Button(action: music.next) {
                Image(systemName: "forward.fill")
            }
            Button { music.onClickRepeat() } label: {
                Image(systemName: music.repeatState() == 2 ? "repeat.1" : "repeat")
                    .foregroundColor(music.repeatState() == 0 ? .gray : .red)
            }
        }
        .buttonStyle(HoverButtonStyle())
        .font(.title2)
    }

    private var volumeSlider: some View {
        ZStack {
            if ui.isDraggingVolume {
                Text("\(Int(volumeValue))")
                    .font(.caption2)
                    .padding(6)
                    .background(.ultraThinMaterial)
                    .cornerRadius(6)
                    .offset(y: -22)
                    .transition(.opacity)
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
                            scheduleVolumeUpdate(Int($0))
                        }
                    ),
                    in: 0...100,
                    onEditingChanged: { editing in
                        withAnimation(.easeOut(duration: 0.15)) {
                            ui.isDraggingVolume = editing
                        }
                    }
                )

                Image(systemName: "speaker.wave.3.fill")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    private func scheduleVolumeUpdate(_ value: Int) {
        volumeTask?.cancel()
        volumeTask = Task {
            try? await Task.sleep(nanoseconds: 80_000_000)
            await MainActor.run {
                music.setVolume(value)
            }
        }
    }

    private func toggleCompact() {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) {
            windowState.isCompact.toggle()
            music.setWindowSize(compact: windowState.isCompact)
            music.setWindowOpacity(compact: windowState.isCompact)
        }
    }
}
