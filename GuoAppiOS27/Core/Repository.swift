import Foundation

/// Mirrors the action surface of guoapp's Dart `AppRepository`. Data-layer concerns
/// (users, follow state, history, UI settings) live in LocalStore, not here.
final class Repository {
    static let shared = Repository()
    private let core = DuanjuCore.shared

    private init() {}

    func initialize() async throws { try await core.initializeIfNeeded() }

    func categories(source: String) async throws -> [String] {
        let data = try await core.request("categories", ["source": source])
        if let list = data["items"] as? [String] { return list }
        if let list = data["categories"] as? [String] { return list }
        return []
    }

    func catalog(source: String, page: Int, category: String? = nil, query: String? = nil,
                 force: Bool = false) async throws -> CatalogResult {
        var payload: [String: Any] = ["source": source, "page": page, "force": force]
        if let category, !category.isEmpty { payload["category"] = category }
        if let query, !query.isEmpty { payload["query"] = query }
        let data = try await core.request("catalog", payload)
        let rawItems = data["items"] as? [[String: Any]] ?? []
        let decoder = JSONDecoder()
        let items = rawItems.compactMap { raw -> Drama? in
            guard let json = try? JSONSerialization.data(withJSONObject: raw) else { return nil }
            return try? decoder.decode(Drama.self, from: json)
        }
        return CatalogResult(
            items: items,
            hasMore: (data["hasMore"] as? Bool) ?? false,
            page: (data["page"] as? Int) ?? page,
            warning: data["warning"] as? String
        )
    }

    func detail(drama: Drama) async throws -> (Drama, [Chapter]) {
        let dramaDict: [String: Any] = [
            "id": drama.id, "source": drama.source, "sourceId": drama.sourceID,
            "title": drama.title, "description": drama.description, "cover": drama.cover,
            "episodes": drama.episodes, "category": drama.category, "tags": drama.tags
        ]
        let data = try await core.request("detail", ["drama": dramaDict])
        var resolved = drama
        if let d = data["drama"] as? [String: Any],
           let obj = try? JSONSerialization.data(withJSONObject: d),
           let parsed = try? JSONDecoder().decode(Drama.self, from: obj) {
            resolved = parsed
        }
        let decoder = JSONDecoder()
        let chapters = (data["chapters"] as? [[String: Any]] ?? []).compactMap { raw -> Chapter? in
            guard let json = try? JSONSerialization.data(withJSONObject: raw) else { return nil }
            return try? decoder.decode(Chapter.self, from: json)
        }
        return (resolved, chapters)
    }

    /// Resolves a playable URL + headers. The Go engine handles HLS rewriting,
    /// key decryption headers, route fallback and local-file playback.
    func resolve(drama: Drama, chapter: Chapter, index: Int, quality: Int = 0) async throws -> [String: Any] {
        let chapterDict: [String: Any] = [
            "id": chapter.id, "source": chapter.source, "title": chapter.title,
            "videoUrl": chapter.videoURL, "currentEpisode": chapter.episode,
            "pageUrl": chapter.pageURL ?? "", "referer": chapter.referer ?? "",
            "vertical": chapter.vertical ?? false
        ]
        let dramaDict: [String: Any] = [
            "id": drama.id, "source": drama.source, "sourceId": drama.sourceID,
            "title": drama.title, "cover": drama.cover, "episodes": drama.episodes
        ]
        return try await core.request("resolve", [
            "drama": dramaDict, "chapter": chapterDict, "index": index,
            "quality": quality, "force": true
        ])
    }

    func danmaku(drama: Drama, chapter: Chapter, startMs: Int64, durationMs: Int64) async throws -> [[String: Any]] {
        let dramaDict: [String: Any] = ["id": drama.id, "source": drama.source]
        let chapterDict: [String: Any] = ["id": chapter.id, "source": chapter.source, "currentEpisode": chapter.episode]
        let data = try await core.request("danmaku", [
            "drama": dramaDict, "chapter": chapterDict,
            "startMs": startMs, "durationMs": durationMs
        ])
        return data["items"] as? [[String: Any]] ?? []
    }

    func suggestions(source: String, query: String) async throws -> [String] {
        let data = try await core.request("suggestions", ["source": source, "query": query])
        return data["items"] as? [String] ?? []
    }

    func moduleList() async throws -> [[String: Any]] {
        let data = try await core.request("modules", [:])
        return data["items"] as? [[String: Any]] ?? []
    }

    func release() async {
        try? await core.request("release", [:])
    }
}
