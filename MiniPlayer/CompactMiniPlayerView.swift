import SwiftUI

struct CompactMiniPlayerView: View {
    let music: MusicDataService
    let windowState: WindowState
    
    @State private var progress: Double = 0
    @State private var current: String = "--:--"
    @State private var duration: String = "--:--"
    @State private var isDragging = false
    @State private var dragProgress: Double = 0
    
    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                artworkView
                
                titleBlock
                
                Spacer(minLength: 8)
                
                controlButtons
            }
            .padding(.horizontal, 8)
            .padding(.top, 6)
            
            VStack(spacing: 2) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(music.isDarkBackground ? Color.white.opacity(0.4) : Color.black.opacity(0.3))
                            .frame(height: 4)

                        Capsule()
                            .fill(music.isDarkBackground ? Color.white : Color.black)
                            .frame(width: barWidth(in: geo), height: 4)
                    }
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                isDragging = true
                                let x = max(0, min(value.location.x, geo.size.width))
                                dragProgress = Double(x / geo.size.width)
                            }
                            .onEnded { value in
                                let x = max(0, min(value.location.x, geo.size.width))
                                let final = Double(x / geo.size.width)
                                seek(to: final)
                                isDragging = false
                            }
                    )
                    .onHover { hovering in
                        if hovering { NSCursor.pointingHand.push() }
                        else { NSCursor.pop() }
                    }
                }
                .frame(height: 8)
                .padding(.horizontal, 8)
                
                HStack {
                    Text(current)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text(duration)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 8)
            }
            .padding(.vertical, 8)
        }
        .onAppear {
            Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { _ in
                if !isDragging, let pos = music.getPlayerPosition() {
                    progress = pos.current / max(pos.duration, 1)
                    current = formatTime(pos.current)
                    duration = formatTime(pos.duration)
                }
            }
        }
    }
    
    private var artworkView: some View {
        ZStack {
            if let img = music.albumArt {
                Image(nsImage: img)
                    .resizable()
                    .frame(width: 80, height: 80)
                    .cornerRadius(8)
                    .shadow(radius: 5)
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
        .animation(.easeOut(duration: 0.28), value: music.albumArt)
    }
    
    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 2) {
            MarqueeText(
                text: music.trackName,
                font: NSFont.systemFont(ofSize: 14, weight: .medium),
                leftFade: 16,
                rightFade: 16,
                startDelay: 2,
                alignment: .leading
            )
            
            MarqueeText(
                text: music.artistName,
                font: NSFont.systemFont(ofSize: 12, weight: .thin),
                leftFade: 16,
                rightFade: 16,
                startDelay: 2,
                alignment: .leading
            )
            
            MarqueeText(
                text: music.albumName,
                font: NSFont.systemFont(ofSize: 12, weight: .thin),
                leftFade: 16,
                rightFade: 16,
                startDelay: 2,
                alignment: .leading
            )
        }
    }
    
    private var controlButtons: some View {
        HStack(spacing: 16) {
            Button(action: music.toggle) {
                Image(systemName: music.isPlaying ? "pause.fill" : "play.fill")
                    .font(.title2)
            }
            
            Button(action: music.next) {
                Image(systemName: "forward.fill")
                    .font(.title2)
            }
        }
        .buttonStyle(.borderless)
    }
    
    private func barWidth(in geo: GeometryProxy) -> CGFloat {
        let p = isDragging ? dragProgress : progress
        return geo.size.width * CGFloat(p)
    }
    
    private func seek(to p: Double) {
        if let durationSec = music.getPlayerPosition()?.duration {
            let target = durationSec * p
            music.setPlayerPosition(to: target)
        }
    }
    
    private func formatTime(_ sec: Double) -> String {
        guard sec.isFinite else { return "--:--" }
        let m = Int(sec) / 60
        let s = Int(sec) % 60
        return String(format: "%d:%02d", m, s)
    }
}
