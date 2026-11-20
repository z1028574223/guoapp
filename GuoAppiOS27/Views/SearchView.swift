import SwiftUI

/// Keyword search across the active source: suggestions + catalog(query:).
struct SearchView: View {
    @EnvironmentObject var store: LocalStore
    @State private var query = ""
    @State private var results: [RemoteDrama] = []
    @State private var suggestions: [String] = []
    @State private var searching = false
    @State private var searched = false
    @State private var message: String?
    @State private var route: RemoteDrama?
    let source: String

    private var trimmed: String { query.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        VStack(spacing: 0) {
            // Search field on glass
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("搜索剧名", text: $query)
                    .textFieldStyle(.plain)
                    .submitLabel(.search)
                    .onSubmit { Task { await search() } }
                if !query.isEmpty {
                    Button { query = ""; results = []; searched = false } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary)
                    }
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            .adaptiveGlass(level: store.settings.glassLevel,
                           in: AnyShape(RoundedRectangle(cornerRadius: 16)))
            .padding(.horizontal).padding(.top, 6)

            // Suggestions
            if !suggestions.isEmpty && !searched {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(suggestions, id: \.self) { s in
                            Button { query = s; Task { await search() } } label: {
                                Text(s).font(.caption).padding(.horizontal, 12).padding(.vertical, 7)
                            }
                            .adaptiveGlass(level: store.settings.glassLevel,
                                           in: AnyShape(Capsule()), interactive: true)
                        }
                    }.padding(.horizontal).padding(.top, 10)
                }
            }

            if let message {
                Text(message).font(.caption).foregroundStyle(.secondary)
                    .padding(.top, 12)
            }

            ScrollView {
                if searching {
                    ProgressView().padding(.top, 40)
                } else if results.isEmpty && searched {
                    VStack(spacing: 10) {
                        Image(systemName: "magnifyingglass").font(.system(size: 40))
                            .foregroundStyle(.tertiary)
                        Text("没有找到相关短剧").font(.subheadline).foregroundStyle(.secondary)
                    }.padding(.top, 60)
                } else {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                        ForEach(results) { drama in
                            Button { route = drama } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    AsyncCover(cover: drama.cover, level: store.settings.glassLevel)
                                        .frame(width: 112, height: 158).clipped()
                                        .clipShape(RoundedRectangle(cornerRadius: 14))
                                    Text(drama.title).font(.caption.weight(.semibold))
                                        .lineLimit(1).frame(width: 112, alignment: .leading)
                                    Text("\(drama.episodes)集 · \(drama.category)")
                                        .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                                }
                            }.buttonStyle(.plain)
                        }
                    }.padding()
                }
            }

            // Recent searches
            if !store.recentSearches.isEmpty && !searched {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("最近搜索").font(.caption.bold()).foregroundStyle(.secondary)
                        Spacer()
                        Button("清空") { store.recentSearches = [] }
                            .font(.caption).foregroundStyle(GlassTokens.accent)
                    }
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(store.recentSearches, id: \.self) { s in
                                Button { query = s; Task { await search() } } label: {
                                    Text(s).font(.caption2).padding(.horizontal, 10).padding(.vertical, 6)
                                }
                                .adaptiveGlass(level: store.settings.glassLevel,
                                               in: AnyShape(Capsule()), interactive: true)
                            }
                        }
                    }
                }.padding(.horizontal).padding(.bottom, 10)
            }
        }
        .navigationTitle("搜索")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $route) { drama in
            DetailView(drama: drama.asDrama)
        }
        .task {
            if !trimmed.isEmpty { await search() }
        }
        .onChange(of: query) { newValue in
            Task {
                if newValue.count >= 1 && !newValue.isEmpty {
                    if let s = try? await Repository.shared.suggestions(source: source, query: newValue) {
                        suggestions = Array(s.prefix(8))
                    }
                } else {
                    suggestions = []
                }
            }
        }
    }

    func search() async {
        let q = trimmed
        guard !q.isEmpty else { return }
        searching = true
        defer { searching = false }
        do {
            let data = try await Repository.shared.catalogRaw(source: source, page: 1, query: q)
            let catalog = RemoteCatalog(data)
            results = catalog.items
            searched = true
            message = catalog.warning
            store.addRecentSearch(q)
        } catch {
            message = "搜索失败：\(error.localizedDescription)"
            searched = true
        }
    }
}
