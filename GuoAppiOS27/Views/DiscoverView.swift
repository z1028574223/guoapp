import SwiftUI

struct DiscoverView: View {
    @EnvironmentObject var store: LocalStore
    @State private var categories = ["推荐", "全部", "热播榜", "都市", "甜宠", "悬疑", "古装", "逆袭"]
    @State private var selected = "推荐"
    @State private var source = "红果短剧"
    @State private var items: [Drama] = DemoContent.catalog
    @State private var showDemoBanner = true
    @State private var loading = false
    @State private var route: Drama?

    var level: Double { store.settings.glassLevel }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                // Brand + source switcher floating on glass
                HStack(spacing: 10) {
                    Text("小果影视").font(.title2.bold())
                    Menu {
                        ForEach(DemoContent.sources, id: \.self) { s in
                            Button { source = s; Task { await load() } } label: {
                                Label(s, systemImage: s == source ? "checkmark" : "")
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(source).font(.caption.weight(.semibold))
                            Image(systemName: "chevron.down").font(.caption2)
                        }
                        .padding(.horizontal, 12).padding(.vertical, 7)
                        .adaptiveGlass(level: level, in: AnyShape(Capsule()), interactive: true)
                    }
                    Spacer()
                    Button { } label: {
                        Image(systemName: "magnifyingglass").font(.body.weight(.semibold))
                    }
                    .buttonStyle(.glass)
                    .frame(width: 40, height: 40)
                }
                .padding(.horizontal)

                if showDemoBanner {
                    HStack(spacing: 8) {
                        Image(systemName: "info.circle.fill").foregroundStyle(GlassTokens.accent)
                        Text("当前为演示内容（未安装真实站源模块）")
                            .font(.caption)
                        Spacer()
                        Button { showDemoBanner = false } label: {
                            Image(systemName: "xmark").font(.caption2)
                        }
                    }
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .adaptiveGlass(level: level, in: AnyShape(RoundedRectangle(cornerRadius: 14)))
                    .padding(.horizontal)
                }

                // Category pills
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 9) {
                        ForEach(categories, id: \.self) { cat in
                            Button {
                                selected = cat
                                Task { await load() }
                            } label: {
                                Text(cat).font(.subheadline.weight(.semibold))
                                    .padding(.horizontal, 17).padding(.vertical, 8)
                            }
                            .adaptiveGlass(level: selected == cat ? 0.9 : level,
                                           in: AnyShape(Capsule()), interactive: true)
                            .foregroundStyle(selected == cat ? Color.primary : .secondary)
                        }
                    }
                    .padding(.horizontal)
                }

                // Hero card
                if let hero = items.first {
                    Button { route = hero } label: {
                        ZStack(alignment: .bottomLeading) {
                            Image(hero.cover).resizable().scaledToFill()
                                .frame(height: 210).clipped()
                            LinearGradient(colors: [.clear, .black.opacity(0.85)],
                                           startPoint: .center, endPoint: .bottom)
                            VStack(alignment: .leading, spacing: 6) {
                                Text(hero.heat ?? "热播推荐")
                                    .font(.caption2.bold())
                                    .padding(.horizontal, 9).padding(.vertical, 4)
                                    .adaptiveGlass(level: level, in: AnyShape(Capsule()))
                                Text(hero.title).font(.title.bold())
                                Text("\(hero.category) · \(hero.views ?? "")次播放 · 全\(hero.episodes)集")
                                    .font(.caption).foregroundStyle(.white.opacity(0.8))
                            }
                            .padding(18)
                        }
                        .frame(height: 210)
                        .clipShape(RoundedRectangle(cornerRadius: GlassTokens.cornerLarge))
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal)
                }

                // Poster rail
                VStack(alignment: .leading, spacing: 10) {
                    Text("正在热播").font(.headline).padding(.horizontal)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(Array(items.enumerated()), id: \.element.key) { idx, drama in
                                PosterCard(drama: drama, rank: idx + 1, level: level) {
                                    route = drama
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }

                // Grid
                VStack(alignment: .leading, spacing: 10) {
                    Text("为你推荐").font(.headline).padding(.horizontal)
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                        ForEach(items.dropFirst(2), id: \.key) { drama in
                            PosterCard(drama: drama, rank: nil, level: level) { route = drama }
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.top, 8)
        }
        .navigationDestination(item: $route) { drama in
            DetailView(drama: drama)
        }
        .task { await load() }
    }

    func load() async {
        loading = true
        defer { loading = false }
        // Real data comes from the Go core once a station module is installed.
        // The bundled example module only returns synthetic rows; keep demo
        // content when the source returns nothing usable.
        do {
            let result = try await Repository.shared.catalog(source: source, page: 1, category: selected)
            if !result.items.isEmpty {
                items = result.items
                showDemoBanner = false
            }
        } catch {
            // Keep demo content visible.
        }
    }
}

struct PosterCard: View {
    let drama: Drama
    let rank: Int?
    let level: Double
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                ZStack(alignment: .topLeading) {
                    Image(drama.cover).resizable().scaledToFill()
                        .frame(width: 112, height: 158).clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    if let rank {
                        Text("\(rank)").font(.caption.bold())
                            .shadow(radius: 2).padding(6).foregroundStyle(.white)
                    }
                }
                Text(drama.title).font(.caption.weight(.semibold))
                    .lineLimit(1).frame(width: 112, alignment: .leading)
                Text("\(drama.episodes)集 · \(drama.category)")
                    .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
            }
        }
        .buttonStyle(.plain)
    }
}
