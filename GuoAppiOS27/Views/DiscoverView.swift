import SwiftUI

struct DiscoverView: View {
    @EnvironmentObject var store: LocalStore
    @EnvironmentObject var sources: SourceState

    @State private var categories: [String] = []
    @State private var selected = ""
    @State private var items: [RemoteDrama] = []
    @State private var loading = false
    @State private var route: RemoteDrama?
    @State private var warning: String?
    @State private var showSearch = false

    private var sourceID: String { sources.activeID }
    private var level: Double { store.settings.glassLevel }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                // Brand + source switcher + search
                HStack(spacing: 10) {
                    Text("小果影视").font(.title2.bold())
                    Menu {
                        if sources.sources.isEmpty {
                            Text("暂无可用站源").font(.caption)
                        } else {
                            ForEach(sources.sources) { s in
                                Button {
                                    sources.select(s.id)
                                    Task { await reloadCategories() }
                                } label: {
                                    Label(s.name, systemImage: s.id == sourceID ? "checkmark" : "")
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(sources.name(of: sourceID)).font(.caption.weight(.semibold))
                            Image(systemName: "chevron.down").font(.caption2)
                        }
                        .padding(.horizontal, 12).padding(.vertical, 7)
                        .adaptiveGlass(level: level, in: AnyShape(Capsule()), interactive: true)
                    }
                    Spacer()
                    Button { showSearch = true } label: {
                        Image(systemName: "magnifyingglass").font(.body.weight(.semibold))
                    }.buttonStyle(.glass).frame(width: 40, height: 40)
                }
                .padding(.horizontal)

                if let warning, !warning.isEmpty {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.circle.fill").foregroundStyle(.orange)
                        Text(warning).font(.caption).lineLimit(2)
                    }
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .adaptiveGlass(level: level, in: AnyShape(RoundedRectangle(cornerRadius: 14)))
                    .padding(.horizontal)
                }

                // Category pills
                if !categories.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 9) {
                            ForEach(categories, id: \.self) { cat in
                                Button {
                                    selected = cat
                                    Task { await loadItems() }
                                } label: {
                                    Text(cat).font(.subheadline.weight(.semibold))
                                        .padding(.horizontal, 17).padding(.vertical, 8)
                                }
                                .adaptiveGlass(level: selected == cat ? 0.9 : level,
                                               in: AnyShape(Capsule()), interactive: true)
                                .foregroundStyle(selected == cat ? Color.primary : .secondary)
                            }
                        }.padding(.horizontal)
                    }
                }

                if loading {
                    HStack { Spacer(); ProgressView(); Spacer() }.padding(.top, 40)
                } else if items.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "film.stack").font(.system(size: 44)).foregroundStyle(.tertiary)
                        Text("当前站源没有内容").font(.subheadline).foregroundStyle(.secondary)
                        Text("到「我的 › 站源模块」安装或切换站源")
                            .font(.caption).foregroundStyle(.tertiary)
                    }.frame(maxWidth: .infinity).padding(.top, 50)
                } else {
                    // Hero card
                    if let hero = items.first {
                        Button { route = hero } label: {
                            ZStack(alignment: .bottomLeading) {
                                AsyncCover(cover: hero.cover, level: level)
                                    .frame(height: 210).clipped()
                                LinearGradient(colors: [.clear, .black.opacity(0.85)],
                                               startPoint: .center, endPoint: .bottom)
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(hero.heat ?? "热播推荐")
                                        .font(.caption2.bold()).padding(.horizontal, 9).padding(.vertical, 4)
                                        .adaptiveGlass(level: level, in: AnyShape(Capsule()))
                                    Text(hero.title).font(.title.bold())
                                    Text("\(hero.category) · \(hero.views ?? "")次播放 · 全\(hero.episodes)集")
                                        .font(.caption).foregroundStyle(.white.opacity(0.8))
                                }.padding(18)
                            }
                            .frame(height: 210)
                            .clipShape(RoundedRectangle(cornerRadius: GlassTokens.cornerLarge))
                        }.buttonStyle(.plain).padding(.horizontal)
                    }

                    // Grid
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                        ForEach(items) { drama in
                            PosterCard(drama: drama, level: level) { route = drama }
                        }
                    }.padding(.horizontal)
                }
            }.padding(.top, 8)
        }
        .refreshable { await loadItems() }
        .navigationDestination(item: $route) { drama in
            DetailView(drama: drama.asDrama)
        }
        .navigationDestination(isPresented: $showSearch) {
            SearchView(source: sourceID)
        }
        .task {
            await reloadCategories()
        }
        .onChange(of: sourceID) { _ in Task { await reloadCategories() } }
    }

    func reloadCategories() async {
        guard !sourceID.isEmpty else { return }
        do {
            let list = try await Repository.shared.categories(source: sourceID)
            categories = list.isEmpty ? ["推荐"] : list
            selected = categories.first ?? "推荐"
            await loadItems()
        } catch {
            categories = ["推荐"]
            selected = "推荐"
            await loadItems()
        }
    }

    func loadItems() async {
        guard !sourceID.isEmpty else { return }
        loading = true
        defer { loading = false }
        do {
            let cat = (selected == "推荐" || selected.isEmpty) ? nil : selected
            let data = try await Repository.shared.catalogRaw(source: sourceID, page: 1, category: cat)
            let result = RemoteCatalog(data)
            items = result.items
            warning = result.warning
        } catch {
            warning = "加载失败：\(error.localizedDescription)"
        }
    }
}

struct PosterCard: View {
    let drama: RemoteDrama
    let level: Double
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                AsyncCover(cover: drama.cover, level: level)
                    .frame(width: 112, height: 158).clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                Text(drama.title).font(.caption.weight(.semibold))
                    .lineLimit(1).frame(width: 112, alignment: .leading)
                Text("\(drama.episodes)集 · \(drama.category)")
                    .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
            }
        }.buttonStyle(.plain)
    }
}
