import SwiftUI

/// Loads a drama cover from either a remote URL (real site modules) or a
/// bundled resource name (demo content), with a graceful placeholder fallback.
struct AsyncCover: View {
    let cover: String
    let level: Double

    private var isRemote: Bool {
        cover.hasPrefix("http://") || cover.hasPrefix("https://")
    }

    var body: some View {
        ZStack {
            if isRemote, let url = URL(string: cover) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    case .failure, .empty:
                        placeholder
                    @unknown default:
                        placeholder
                    }
                }
            } else if !cover.isEmpty {
                Image(cover).resizable().scaledToFill()
            } else {
                placeholder
            }
        }
    }

    private var placeholder: some View {
        ZStack {
            LinearGradient(colors: [.purple.opacity(0.5), .orange.opacity(0.35)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            Image(systemName: "film.stack.fill")
                .font(.largeTitle).foregroundStyle(.white.opacity(0.7))
        }
    }
}

/// Decodes a [String: Any] drama dict from the Go core into a display model.
struct RemoteDrama: Identifiable, Hashable {
    // Hash by id only; the `raw` dict is [String: Any] and cannot participate
    // in synthesized Hashable/Equatable conformance.
    static func == (lhs: RemoteDrama, rhs: RemoteDrama) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    let id: String
    let source: String
    let sourceID: String
    let title: String
    let description: String
    let cover: String
    let episodes: Int
    let category: String
    let heat: String?
    let views: String?
    let score: String?
    let tags: [String]
    let releaseStatus: String?

    /// Raw dict kept for actions that need the original LibraryDrama payload.
    let raw: [String: Any]

    init?(_ dict: [String: Any]) {
        guard let id = dict["id"] as? String,
              let source = dict["source"] as? String else { return nil }
        self.id = id
        self.source = source
        self.sourceID = dict["sourceId"] as? String ?? ""
        self.title = dict["title"] as? String ?? "未命名"
        self.description = dict["description"] as? String ?? ""
        self.cover = dict["cover"] as? String ?? ""
        self.episodes = dict["episodes"] as? Int ?? 0
        self.category = dict["category"] as? String ?? ""
        self.heat = dict["heat"] as? String
        self.views = dict["views"] as? String
        self.score = dict["score"] as? String
        self.tags = dict["tags"] as? [String] ?? []
        self.releaseStatus = dict["releaseStatus"] as? String
        self.raw = dict
    }

    /// Convert back to a Drama for the Go core detail/resolve actions.
    var asDrama: Drama {
        Drama(id: id, source: source, sourceID: sourceID, title: title,
              description: description, cover: cover, episodes: episodes,
              category: category, heat: heat, views: views, tags: tags,
              releaseStatus: releaseStatus, score: score)
    }
}

/// Parses the standard catalog result dict from the Go core.
struct RemoteCatalog {
    var items: [RemoteDrama]
    var hasMore: Bool
    var warning: String?
    var localSearch: Bool

    init(_ data: [String: Any]) {
        let raw = data["items"] as? [[String: Any]] ?? []
        self.items = raw.compactMap { RemoteDrama($0) }
        self.hasMore = data["hasMore"] as? Bool ?? false
        self.warning = data["warning"] as? String
        self.localSearch = data["localSearch"] as? Bool ?? false
    }
}
