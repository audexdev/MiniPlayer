import SwiftUI

struct CompactMiniPlayerView: View {
    @EnvironmentObject var music: MusicDataService
    @EnvironmentObject var windowState: WindowState
    @EnvironmentObject var ui: PlayerUIState

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                artworkView
                titleBlock
                Spacer(minLength: 8)
                controlButtons
            }
            .padding(.horizontal, 8)
            .padding(.top, 6)

            progressSection
        }
        .padding(.horizontal, 8)
    }

    private var artworkView: some View {
        ZStack {
            if let img = music.albumArt {
                Image(nsImage: img)
                    .resizable()
                    .frame(width: 80, height: 80)
                    .cornerRadius(8)
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 8).fill(Color.gray.opacity(0.2))
                    Image(systemName: "music.note")
                        .font(.largeTitle)
                        .foregroundColor(.gray)
                }
                .frame(width: 80, height: 80)
            }
        }
        .onTapGesture {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) {
                windowState.isCompact.toggle()
                music.setWindowSize(compact: windowState.isCompact)
                music.setWindowOpacity(compact: windowState.isCompact)
            }
        }
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 2) {
            MarqueeText(
                text: music.trackName,
                font: NSFont.systemFont(ofSize: 14, weight: .medium),
                leftFade: 16, rightFade: 16, startDelay: 3, alignment: .leading
            )
            MarqueeText(
                text: music.artistName,
                font: NSFont.systemFont(ofSize: 12, weight: .thin),
                leftFade: 16, rightFade: 16, startDelay: 3, alignment: .leading
            )
            MarqueeText(
                text: music.albumName,
                font: NSFont.systemFont(ofSize: 12, weight: .thin),
                leftFade: 16, rightFade: 16, startDelay: 3, alignment: .leading
            )
        }
    }

    private var controlButtons: some View {
        HStack(spacing: 16) {
            Button(action: music.toggle) {
                Image(systemName: music.isPlaying ? "pause.fill" : "play.fill")
            }
            Button(action: music.next) {
                Image(systemName: "forward.fill")
            }
        }
        .font(.title2)
        .buttonStyle(.borderless)
    }

    private var progressSection: some View {
        VStack(spacing: 2) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(music.isDarkBackground ? Color.white.opacity(0.4) :
                                                        Color.black.opacity(0.3))
                        .frame(height: 4)

                    Capsule()
                        .fill(music.isDarkBackground ? Color.white : Color.black)
                        .frame(width: geo.size.width * ui.progress(), height: 4)
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            ui.isDragging = true
                            let x = max(0, min(value.location.x, geo.size.width))
                            ui.dragProgress = Double(x / geo.size.width)
                        }
                        .onEnded { value in
                            let x = max(0, min(value.location.x, geo.size.width))
                            ui.dragProgress = Double(x / geo.size.width)
                            if let duration = music.getPlayerPosition()?.duration {
                                let target = duration * ui.dragProgress
                                music.setPlayerPosition(to: target)
                            }
                            ui.isDragging = false
                        }
                )
            }
            .frame(height: 8)
            .padding(.horizontal, 8)

            HStack {
                Text(ui.formattedCurrent)
                    .font(.caption2).foregroundColor(.secondary)
                
                Spacer()
                
                HStack() {
                    if music.codec == .atmos {
                        Image("Dolby_Atmos")
                            .resizable()
                            .interpolation(.high)
                            .antialiased(false)
                            .renderingMode(.template)
                            .foregroundColor(.secondary)
                            .frame(width: 89.6, height: 12.6)
                            .fixedSize()
                    } else if music.codec == .lossless {
                        Image("Lossless")
                            .resizable()
                            .interpolation(.none)
                            .antialiased(false)
                            .renderingMode(.template)
                            .foregroundColor(.secondary)
                            .frame(width: 15, height: 9)
                            .fixedSize()
                    }

                    if music.codec != .atmos {
                        Text(music.qualityLabel)
                            .font(.system(size: 10, weight: .light))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .layoutPriority(10)
                
                Spacer()
                
                Text(ui.formattedDuration)
                    .font(.caption2).foregroundColor(.secondary)
            }
            .padding(.horizontal, 8)
        }
        .padding(.vertical, 8)
    }
}
