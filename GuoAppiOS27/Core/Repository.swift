import Foundation

/// Mirrors guoapp's Dart `AppRepository` / NativeRepository. Every method maps
/// to one `action` handled by the Go core via DuanjuRequest(char*).
///
/// Payloads use [String: Any] on purpose: the Go core's JSON has many optional
/// fields and raw JSON values, so dictionaries tolerate field changes better
/// than strict Codable models.
final class Repository {
    static let shared = Repository()
    private let core = DuanjuCore.shared

    /// The Go core requires a strictly increasing playback sequence for every
    /// resolve/fallback/cancelPlayback call. Starting from a timestamp mirrors
    /// guoapp's Dart layer (`_playbackSequence = DateTime.now().microsecondsSinceEpoch`).
    /// Without this, nativeBeginPlayback rejects the request with context.Canceled,
    /// which makes ALL playback fail. Access is serialized via the core's queue.
    private var playbackSequence: Int64 = Int64(Date().timeIntervalSince1970 * 1_000_000)
    private let sequenceLock = NSLock()

    private func nextPlaybackSequence() -> Int64 {
        sequenceLock.lock()
        defer { sequenceLock.unlock() }
        playbackSequence += 1
        return playbackSequence
    }

    private init() {}

    // MARK: - Lifecycle

    func initialize() async throws { try await core.initializeIfNeeded() }

    /// Sources reported by the Go core after initialize (bundled + installed).
    func bootstrapSources() async throws -> [[String: Any]] {
        let data = try await core.request("initialize", [:])
        return data["sources"] as? [[String: Any]] ?? []
    }

    // MARK: - Discovery (kept original signatures for existing views)

    func categories(source: String, force: Bool = false) async throws -> [String] {
        let data = try await core.request("categories", ["source": source, "force": force])
        if let list = data["items"] as? [String] { return list }
        if let list = data["categories"] as? [String] { return list }
        return []
    }

    /// Raw catalog result (used by new views that need warning/localSearch/etc).
    func catalogRaw(source: String, page: Int, category: String? = nil, query: String? = nil,
                    force: Bool = false, session: String? = nil, sequence: Int64 = 0) async throws -> [String: Any] {
        var payload: [String: Any] = ["source": source, "page": page, "force": force]
        if let category, !category.isEmpty { payload["category"] = category }
        if let query, !query.isEmpty { payload["query"] = query }
        if let session { payload["session"] = session; payload["sequence"] = sequence }
        return try await core.request("catalog", payload)
    }

    func catalog(source: String, page: Int, category: String? = nil, query: String? = nil,
                 force: Bool = false) async throws -> CatalogResult {
        let data = try await catalogRaw(source: source, page: page, category: category,
                                        query: query, force: force)
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

    /// Keyword search = catalog with query; no separate Go action exists.
    func search(source: String, query: String, page: Int = 1) async throws -> CatalogResult {
        try await catalog(source: source, page: page, query: query)
    }

    func suggestions(source: String, query: String) async throws -> [String] {
        let data = try await core.request("suggestions", ["source": source, "query": query])
        return data["items"] as? [String] ?? []
    }

    func detailRaw(drama: Drama) async throws -> [String: Any] {
        try await core.request("detail", ["drama": drama.dictionary])
    }

    func detail(drama: Drama) async throws -> (Drama, [Chapter]) {
        let data = try await detailRaw(drama: drama)
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

    func resolve(drama: Drama, chapter: Chapter, index: Int, quality: Int = 0,
                 force: Bool = true) async throws -> [String: Any] {
        try await core.request("resolve", [
            "drama": drama.dictionary, "chapter": chapter.dictionary,
            "index": index, "quality": quality, "force": force,
            "sequence": nextPlaybackSequence()
        ])
    }

    /// Switch to the next playback route for an existing session.
    func fallback(session: String) async throws -> [String: Any] {
        try await core.request("fallback", [
            "session": session, "sequence": nextPlaybackSequence()
        ])
    }

    func danmaku(drama: Drama, chapter: Chapter, startMs: Int64, durationMs: Int64,
                 session: String = "", sequence: Int64 = 0) async throws -> [[String: Any]] {
        var payload: [String: Any] = [
            "drama": drama.dictionary, "chapter": chapter.dictionary,
            "startMs": startMs, "durationMs": durationMs
        ]
        if !session.isEmpty { payload["session"] = session; payload["sequence"] = sequence }
        let data = try await core.request("danmaku", payload)
        return data["items"] as? [[String: Any]] ?? []
    }

    // MARK: - Discovery extras

    func rankingBoards() async throws -> [[String: Any]] {
        let data = try await core.request("rankingBoards", [:])
        return data["items"] as? [[String: Any]] ?? []
    }

    func rankings(board: String, page: Int = 1, force: Bool = false) async throws -> [String: Any] {
        try await core.request("rankings", ["board": board, "page": page, "force": force])
    }

    func recommendations(source: String, category: String, more: Bool = false,
                         force: Bool = false) async throws -> [String: Any] {
        var payload: [String: Any] = ["source": source, "category": category, "force": force]
        if more { payload["command"] = "more" }
        return try await core.request("recommendations", payload)
    }

    func cachedRecommendations(source: String, category: String) async throws -> [String: Any] {
        try await core.request("cachedRecommendations", ["source": source, "category": category])
    }

    func cached(source: String, category: String) async throws -> [String: Any] {
        try await core.request("cached", ["source": source, "category": category])
    }

    func seasons(drama: Drama) async throws -> [[String: Any]] {
        let data = try await core.request("seasons", ["drama": drama.dictionary])
        return data["items"] as? [[String: Any]] ?? []
    }

    func followCheck(drama: Drama) async throws -> [String: Any] {
        try await core.request("followCheck", ["drama": drama.dictionary])
    }

    func metadata(drama: Drama) async throws -> [String: Any] {
        try await core.request("metadata", ["drama": drama.dictionary])
    }

    func cover(drama: Drama, force: Bool = false) async throws -> [String: Any] {
        try await core.request("cover", ["drama": drama.dictionary, "force": force])
    }

    func prepareCover(drama: Drama) async throws -> [String: Any] {
        try await core.request("prepareCover", ["drama": drama.dictionary])
    }

    // MARK: - Modules

    func modules() async throws -> [[String: Any]] {
        let data = try await core.request("modules", [:])
        return data["items"] as? [[String: Any]] ?? []
    }

    /// Original name kept for compatibility.
    func moduleList() async throws -> [[String: Any]] { try await modules() }

    func moduleIndex() async throws -> [String: Any] {
        try await core.request("moduleIndex", [:])
    }

    /// Returns a module info dict with a `token` for installModule.
    func prepareModule(indexed id: String, bundled: Bool = false) async throws -> [String: Any] {
        try await core.request("prepareModule", ["source": id, "bundled": bundled])
    }

    func prepareModule(file path: String) async throws -> [String: Any] {
        try await core.request("prepareModule", ["file": path])
    }

    func prepareModule(url: String) async throws -> [String: Any] {
        try await core.request("prepareModule", ["url": url])
    }

    @discardableResult
    func installModule(token: String) async throws -> [[String: Any]] {
        let data = try await core.request("installModule", ["token": token])
        return data["sources"] as? [[String: Any]] ?? []
    }

    @discardableResult
    func uninstallModule(source: String) async throws -> [[String: Any]] {
        let data = try await core.request("uninstallModule", ["source": source])
        return data["sources"] as? [[String: Any]] ?? []
    }

    @discardableResult
    func sourceDevices(source: String, register: Bool = false) async throws -> Bool {
        var payload: [String: Any] = ["source": source]
        if register { payload["command"] = "register" }
        let data = try await core.request("sourceDevices", payload)
        return data["ready"] as? Bool ?? false
    }

    func sourceAccount(source: String, command: String, account: Any? = nil) async throws -> [String: Any] {
        var payload: [String: Any] = ["source": source, "command": command]
        if let account { payload["account"] = account }
        return try await core.request("sourceAccount", payload)
    }

    // MARK: - Downloads

    func downloads(since: String = "") async throws -> [String: Any] {
        try await core.request("downloads", ["since": since])
    }

    @discardableResult
    func enqueueDownloads(drama: Drama, chapters: [(Chapter, Int)], quality: Int,
                          force: Bool = false) async throws -> Int {
        let entries: [[String: Any]] = chapters.map { chapter, index in
            ["chapter": chapter.dictionary, "index": index]
        }
        let data = try await core.request("enqueueDownloads", [
            "drama": drama.dictionary, "entries": entries,
            "quality": quality, "force": force
        ])
        return data["added"] as? Int ?? 0
    }

    @discardableResult
    func controlDownloads(jobId: String, command: String) async throws -> Bool {
        let data = try await core.request("controlDownloads", ["jobId": jobId, "command": command])
        return data["true"] as? Bool ?? true
    }

    func controlDownloadBatch(jobIds: [String], command: String) async throws -> [String: Any] {
        try await core.request("controlDownloadBatch", ["jobIds": jobIds, "command": command])
    }

    func downloadDirectory() async throws -> String {
        let data = try await core.request("downloadDirectory", [:])
        return data["directory"] as? String ?? ""
    }

    func moveDownloads(directory: String) async throws -> [String: Any] {
        try await core.request("moveDownloads", ["directory": directory])
    }

    func beginConversion(jobId: String) async throws -> [String: Any] {
        try await core.request("beginConversion", ["jobId": jobId])
    }

    @discardableResult
    func finishConversion(jobId: String, command: String) async throws -> Bool {
        let data = try await core.request("finishConversion", ["jobId": jobId, "command": command])
        return data["true"] as? Bool ?? true
    }

    // MARK: - Settings / Storage

    func resourceSettings() async throws -> [String: Any] {
        try await core.request("resourceSettings", [:])
    }

    @discardableResult
    func saveResourceSettings(_ settings: [String: Any]) async throws -> [String: Any] {
        try await core.request("saveResourceSettings", ["settings": settings])
    }

    func storage() async throws -> [String: Any] {
        try await core.request("storage", [:])
    }

    func cacheBytes() async throws -> Int64 {
        let data = try await core.request("cache", [:])
        return data["bytes"] as? Int64 ?? 0
    }

    @discardableResult
    func clearCache() async throws -> Bool {
        let data = try await core.request("clearCache", [:])
        return data["true"] as? Bool ?? true
    }

    func checkUpdate(version: String) async throws -> [String: Any] {
        try await core.request("checkUpdate", ["version": version])
    }

    @discardableResult
    func updateSystemProxy(http: String, https: String, bypass: [String], pac: Bool = false) async throws -> Bool {
        let proxy: [String: Any] = ["http": http, "https": https, "bypass": bypass, "pac": pac]
        let data = try await core.request("updateSystemProxy", ["systemProxy": proxy])
        return data["true"] as? Bool ?? true
    }

    @discardableResult
    func reportUsage(version: String) async throws -> Bool {
        let data = try await core.request("reportUsage", ["version": version])
        return data["true"] as? Bool ?? true
    }

    @discardableResult
    func deleteAllData() async throws -> [String] {
        let data = try await core.request("deleteAllData", [:])
        return data["leftover"] as? [String] ?? []
    }

    // MARK: - Casting (upstream iOS does not expose casting; kept for completeness)

    func cast(command: String, extra: [String: Any] = [:]) async throws -> [String: Any] {
        var payload = extra
        payload["command"] = command
        return try await core.request("cast", payload)
    }

    func castDevices() async throws -> [[String: Any]] {
        let data = try await cast(command: "discover")
        return data["items"] as? [[String: Any]] ?? []
    }

    // MARK: - Playback helpers

    func localPlayback(drama: Drama, index: Int) async throws -> [String: Any] {
        try await core.request("localPlayback", ["drama": drama.dictionary, "index": index])
    }

    func preload(drama: Drama, chapter: Chapter, index: Int, quality: Int,
                 session: String, sequence: Int64) async throws -> [String: Any] {
        try await core.request("preload", [
            "drama": drama.dictionary, "chapter": chapter.dictionary,
            "index": index, "quality": quality, "force": true,
            "session": session, "sequence": sequence
        ])
    }

    @discardableResult
    func cancelPlayback() async throws -> Bool {
        let data = try await core.request("cancelPlayback", ["sequence": nextPlaybackSequence()])
        return data["true"] as? Bool ?? true
    }

    @discardableResult
    func cancelRead(session: String, sequence: Int64) async throws -> Bool {
        let data = try await core.request("cancelRead", ["session": session, "sequence": sequence])
        return data["true"] as? Bool ?? true
    }

    func workLease(jobId: String = "", command: String = "") async throws -> Int {
        let data = try await core.request("workLease", ["jobId": jobId, "command": command])
        return data["count"] as? Int ?? 0
    }

    @discardableResult
    func release() async { try? await core.request("release", [:]) }
}

// MARK: - Dictionary conversion for the Go core

extension Drama {
    /// Matches LibraryDrama on the Go side. Nil optionals are omitted.
    var dictionary: [String: Any] {
        var d: [String: Any] = [
            "id": id, "source": source, "sourceId": sourceID, "title": title,
            "description": description, "cover": cover, "episodes": episodes,
            "category": category, "metadataSchema": 1, "tags": tags
        ]
        if let vip { d["vip"] = vip }
        if let heat { d["heat"] = heat }
        if let views { d["views"] = views }
        if let releaseStatus { d["releaseStatus"] = releaseStatus }
        if let score { d["score"] = score }
        return d
    }
}

extension Chapter {
    /// Matches Chapter on the Go side (`currentEpisode` may be number or string).
    var dictionary: [String: Any] {
        var d: [String: Any] = [
            "id": id, "source": source, "title": title,
            "videoUrl": videoURL, "currentEpisode": episode
        ]
        if let pageURL { d["pageUrl"] = pageURL }
        if let referer { d["referer"] = referer }
        if let vertical { d["vertical"] = vertical }
        return d
    }
}
