import SwiftUI
import AVFoundation

struct PlayerView: View {
    @EnvironmentObject var store: LocalStore
    @Environment(\.dismiss) private var dismiss
    let drama: Drama
    let chapters: [Chapter]

    @State private var episode: Int
    @State private var player: AVPlayer?
    @State private var isPlaying = false
    @State private var controlsVisible = true
    @State private var showSettings = false
    @State private var showEpisodes = false
    @State private var resolveError: String?
    @State private var speed: Double
    @State private var hideTimer: Timer?

    private var level: Double { store.settings.glassLevel }
    private var chapter: Chapter? { chapters.first { $0.episode == episode } }

    init(drama: Drama, chapters: [Chapter]) {
        self.drama = drama
        self.chapters = chapters
        _episode = State(initialValue: 1)
        _speed = State(initialValue: LocalStore.shared.settings.playbackSpeed)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // Video layer
            if let player {
                VideoPlayerLayer(player: player)
                    .ignoresSafeArea()
                    .onTapGesture { toggleControls() }
            } else {
                Image(drama.cover).resizable().scaledToFill().ignoresSafeArea()
                    .blur(radius: 2).opacity(0.5)
                VStack(spacing: 12) {
                    ProgressView().tint(.white)
                    if let resolveError {
                        Text(resolveError).font(.caption).foregroundStyle(.white.opacity(0.7))
                            .multilineTextAlignment(.center).padding(.horizontal, 40)
                    }
                }
            }

            // Top bar
            if controlsVisible {
                VStack {
                    HStack(spacing: 10) {
                        Button { dismiss() } label: {
                            Image(systemName: "chevron.left")
                        }
                        .buttonStyle(.glass).frame(width: 40, height: 40)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(drama.title).font(.subheadline.bold())
                            Text("第 \(episode) 集 · \(speedText)倍速")
                                .font(.caption2).foregroundStyle(.white.opacity(0.7))
                        }
                        Spacer()
                        Button { showEpisodes = true } label: {
                            Image(systemName: "list.bullet")
                        }
                        .buttonStyle(.glass).frame(width: 40, height: 40)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal)
                    Spacer()
                }
                .padding(.top, 8)
            }

            // Center play toggle
            if controlsVisible {
                Button { togglePlay() } label: {
                    Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(.white.opacity(0.9))
                }
            }

            // Bottom glass control dock
            if controlsVisible {
                VStack {
                    Spacer()
                    VStack(spacing: 12) {
                        HStack {
                            Text("第 \(episode) 集").font(.caption)
                            Spacer()
                            Text("倍速 \(speedText)").font(.caption)
                        }
                        .foregroundStyle(.white.opacity(0.8))

                        HStack(spacing: 8) {
                            ControlChip(icon: "gobackward.10", label: "快退") {
                                player?.seek(to: CMTime(seconds: max(0, currentTime() - 10),
                                                        preferredTimescale: 600))
                            }
                            ControlChip(icon: isPlaying ? "pause.fill" : "play.fill", label: isPlaying ? "暂停" : "播放") {
                                togglePlay()
                            }
                            ControlChip(icon: "goforward.10", label: "快进") {
                                player?.seek(to: CMTime(seconds: currentTime() + 10,
                                                        preferredTimescale: 600))
                            }
                            ControlChip(icon: "gauge.with.dots.needle.67percent", label: "倍速") {
                                showSettings = true
                            }
                            ControlChip(icon: "list.bullet", label: "选集") {
                                showEpisodes = true
                            }
                        }
                    }
                    .padding(16)
                    .adaptiveGlass(level: level,
                                   in: AnyShape(RoundedRectangle(cornerRadius: GlassTokens.cornerLarge)))
                    .padding(.horizontal, 12)
                    .padding(.bottom, 20)
                }
            }
        }
        .statusBar(hidden: true)
        .sheet(isPresented: $showSettings) { SettingsSheet(speed: $speed, level: level) }
        .sheet(isPresented: $showEpisodes) {
            EpisodeSheet(drama: drama, chapters: chapters, current: $episode, level: level)
                .presentationDetents([.medium, .large])
        }
        .onChange(of: speed) { _, new in
            player?.rate = isPlaying ? Float(new) : 0
            store.settings.playbackSpeed = new
        }
        .onChange(of: episode) { _, _ in Task { await loadEpisode() } }
        .task { await loadEpisode() }
        .onDisappear {
            player?.pause()
            player = nil
        }
    }

    private var speedText: String {
        speed == floor(speed) ? "\(Int(speed))" : "\(speed)"
    }

    private func currentTime() -> Double {
        player?.currentTime().seconds ?? 0
    }

    private func toggleControls() {
        withAnimation { controlsVisible.toggle() }
        scheduleHide()
    }

    private func scheduleHide() {
        hideTimer?.invalidate()
        hideTimer = Timer.scheduledTimer(withTimeInterval: 3.5, repeats: false) { _ in
            Task { @MainActor in
                if isPlaying { withAnimation { controlsVisible = false } }
            }
        }
    }

    private func togglePlay() {
        guard let player else { return }
        if isPlaying {
            player.pause()
        } else {
            player.rate = Float(speed)
        }
        isPlaying.toggle()
        scheduleHide()
    }

    private func loadEpisode() {
        resolveError = nil
        player?.pause()
        player = nil
        Task {
            guard let chapter else {
                resolveError = "该集暂无可用播放源"
                return
            }
            do {
                let plan = try await Repository.shared.resolve(drama: drama, chapter: chapter,
                                                               index: episode - 1)
                guard let urlString = plan["url"] as? String,
                      let url = URL(string: urlString) else {
                    resolveError = "播放地址无效（演示内容不含真实视频）"
                    return
                }
                let headers = plan["headers"] as? [String: String] ?? [:]
                // The AVURLAssetHTTPHeaderFieldsKey symbol is no longer exposed
                // to Swift in recent SDKs; the string key is the documented
                // equivalent and works the same at runtime.
                let options: [String: Any] = headers.isEmpty ? [:] :
                    ["AVURLAssetHTTPHeaderFieldsKey": headers]
                let asset = AVURLAsset(url: url, options: options)
                let item = AVPlayerItem(asset: asset)
                let newPlayer = AVPlayer(playerItem: item)
                newPlayer.rate = Float(speed)
                await MainActor.run {
                    player = newPlayer
                    isPlaying = true
                }
                store.markWatched(drama, episode: episode)
            } catch {
                resolveError = error.localizedDescription
            }
        }
    }
}

struct VideoPlayerLayer: UIViewRepresentable {
    let player: AVPlayer
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        let layer = AVPlayerLayer(player: player)
        layer.videoGravity = .resizeAspect
        view.layer.addSublayer(layer)
        return view
    }
    func updateUIView(_ uiView: UIView, context: Context) {
        if let layer = uiView.layer.sublayers?.first as? AVPlayerLayer {
            layer.frame = uiView.bounds
        }
    }
}

struct ControlChip: View {
    let icon: String
    let label: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon).font(.title3)
                Text(label).font(.caption2)
            }
            .frame(maxWidth: .infinity, minHeight: 52)
            .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
    }
}

struct SettingsSheet: View {
    @Binding var speed: Double
    let level: Double
    private let speeds = [0.75, 1.0, 1.25, 1.5, 2.0, 3.0]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("播放设置").font(.title3.bold())
            Text("播放倍速").font(.subheadline.weight(.semibold))
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 10) {
                ForEach(speeds, id: \.self) { s in
                    Button {
                        speed = s
                    } label: {
                        Text(s == floor(s) ? "\(Int(s))×" : "\(s)×")
                            .frame(maxWidth: .infinity, minHeight: 42)
                    }
                    .adaptiveGlass(level: speed == s ? 0.95 : level,
                                   in: AnyShape(RoundedRectangle(cornerRadius: 11)), interactive: true)
                }
            }
            Spacer()
        }
        .padding()
        .presentationDetents([.height(280)])
    }
}

struct EpisodeSheet: View {
    let drama: Drama
    let chapters: [Chapter]
    @Binding var current: Int
    let level: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("选集 · \(drama.title)").font(.title3.bold())
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 10) {
                    ForEach(chapters, id: \.id) { ch in
                        Button { current = ch.episode } label: {
                            Text("\(ch.episode)").frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .adaptiveGlass(level: current == ch.episode ? 0.95 : level,
                                       in: AnyShape(RoundedRectangle(cornerRadius: 11)), interactive: true)
                    }
                }
            }
        }
        .padding()
    }
}
