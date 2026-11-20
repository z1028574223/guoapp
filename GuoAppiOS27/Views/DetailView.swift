import SwiftUI

struct DetailView: View {
    @EnvironmentObject var store: LocalStore
    let drama: Drama

    @State private var resolved: Drama?
    @State private var chapters: [Chapter] = []
    @State private var group = 0
    @State private var showEpisodes = false
    @State private var downloadStatus: String?
    @State private var showDownload = false

    private var current: Drama { resolved ?? drama }
    private var level: Double { store.settings.glassLevel }
    private var total: Int { current.episodes }
    private var groupCount: Int { min(30, max(0, total - group * 30)) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ZStack(alignment: .top) {
                    AsyncCover(cover: current.cover, level: level)
                        .frame(height: 300).clipped()
                        .overlay(LinearGradient(colors: [.clear, Color(.systemBackground)],
                                                startPoint: .top, endPoint: .bottom))
                    HStack {
                        Spacer()
                        Button { } label: {
                            Image(systemName: "square.and.arrow.up")
                        }
                        .buttonStyle(.glass).frame(width: 40, height: 40)
                    }
                    .padding()
                }

                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .top, spacing: 14) {
                        AsyncCover(cover: current.cover, level: level)
                            .frame(width: 112, height: 158).clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        VStack(alignment: .leading, spacing: 6) {
                            Text(current.title).font(.title2.bold())
                            Text("\(total)集全 · \(current.releaseStatus ?? "连载中")")
                                .font(.caption).foregroundStyle(.secondary)
                            Text("分类 \(current.category) · \(current.views ?? "")次播放")
                                .font(.caption).foregroundStyle(.secondary)
                            if let score = current.score {
                                Text("评分 \(score)").font(.caption.bold()).foregroundStyle(GlassTokens.accent)
                            }
                        }
                    }

                    HStack(spacing: 7) {
                        ForEach(current.tags, id: \.self) { tag in
                            Text("#\(tag)").font(.caption2)
                                .padding(.horizontal, 9).padding(.vertical, 5)
                                .adaptiveGlass(level: level, in: AnyShape(RoundedRectangle(cornerRadius: 9)))
                                .foregroundStyle(.secondary)
                        }
                    }

                    Text(current.description).font(.subheadline).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack {
                        Text("选集").font(.headline)
                        Spacer()
                        Text("共 \(total) 集").font(.caption).foregroundStyle(.secondary)
                    }

                    if total > 0 {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                let groups = Int(ceil(Double(total) / 30))
                                ForEach(0..<groups, id: \.self) { g in
                                    Button {
                                        group = g
                                    } label: {
                                        Text(g == 0 ? "1-30" : "\(g * 30 + 1)-\(min((g + 1) * 30, total))")
                                            .font(.caption.weight(.semibold))
                                            .padding(.horizontal, 13).padding(.vertical, 7)
                                    }
                                    .adaptiveGlass(level: group == g ? 0.95 : level,
                                                   in: AnyShape(Capsule()), interactive: true)
                                }
                            }
                        }

                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 9) {
                            ForEach(0..<groupCount, id: \.self) { i in
                                let ep = group * 30 + i + 1
                                Button { showEpisodes = true } label: {
                                    Text("\(ep)").font(.subheadline.weight(.medium))
                                        .frame(maxWidth: .infinity, minHeight: 42)
                                }
                                .adaptiveGlass(level: isWatched(ep) ? 0.02 : level,
                                               in: AnyShape(RoundedRectangle(cornerRadius: 11)), interactive: true)
                                .foregroundStyle(isWatched(ep) ? .tertiary : .primary)
                            }
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 12) {
                NavigationLink {
                    PlayerView(drama: current, chapters: chapters)
                } label: {
                    HStack {
                        Image(systemName: "play.fill")
                        Text("立即播放").font(.headline)
                    }
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .foregroundStyle(.white)
                    .background(LinearGradient(colors: [.orange, .pink],
                                               startPoint: .topLeading, endPoint: .bottomTrailing))
                    .clipShape(Capsule())
                }
                Button { showDownload = true } label: {
                    Image(systemName: "square.and.arrow.down")
                        .frame(width: 50, height: 50)
                }
                .adaptiveGlass(level: level, in: AnyShape(Capsule()), interactive: true)
                Button {
                    store.toggleFollow(current)
                } label: {
                    Image(systemName: store.isFollowed(current.key) ? "checkmark" : "plus")
                        .frame(width: 50, height: 50)
                }
                .adaptiveGlass(level: level, in: AnyShape(Capsule()), interactive: true)
            }
            .padding(.horizontal).padding(.vertical, 8)
            .background(.bar)
        }
        .sheet(isPresented: $showDownload) {
            DownloadPicker(chapters: chapters, drama: current, status: $downloadStatus)
                .presentationDetents([.medium, .large])
        }
        .task {
            do {
                let result = try await Repository.shared.detail(drama: drama)
                resolved = result.0
                chapters = result.1
            } catch {
                // Demo mode: synthesize episodes so playback flow stays testable.
                if chapters.isEmpty {
                    chapters = (1...max(1, drama.episodes)).map { i in
                        Chapter(id: "\(drama.key)-\(i)", source: drama.source,
                                title: "第\(i)集", videoURL: "", episode: i,
                                pageURL: nil, referer: nil, vertical: true)
                    }
                }
            }
        }
    }

    private func isWatched(_ ep: Int) -> Bool {
        (store.followStates[current.key]?.readEpisodes ?? 0) >= ep
    }
}
