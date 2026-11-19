import Foundation
import Combine

struct FollowState: Codable {
    var knownEpisodes: Int = 0
    var readEpisodes: Int = 0
    var seriesSeasons: [Int] = []
    var addedAt: Date = Date()

    var newEpisodes: Int { max(0, knownEpisodes - readEpisodes) }
}

struct WatchEntry: Codable, Identifiable {
    var id: String { dramaKey + "#\(episode)" }
    var dramaKey: String
    var title: String
    var cover: String
    var source: String
    var episode: Int
    var updatedAt: Date = Date()
}

struct Settings: Codable {
    var glassLevel: Double = 0.35
    var themeMode: String = "system"
    var playbackSpeed: Double = 1.0
    var danmakuEnabled: Bool = true
}

/// Local, per-device user data. Go core has no concept of users, follow state or
/// history — this store reconstructs the subset needed by the UI (mirrors guoapp's
/// LocalStore, simplified to a single JSON file for this prototype).
final class LocalStore: ObservableObject {
    static let shared = LocalStore()

    @Published var favorites: [String: Drama] = [:] {
        didSet { save() }
    }
    @Published var followStates: [String: FollowState] = [:] {
        didSet { save() }
    }
    @Published var history: [WatchEntry] = [] {
        didSet { save() }
    }
    @Published var settings = Settings() {
        didSet { save() }
    }

    private let file: URL
    private var isLoading = true

    private init() {
        let support = try! FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask,
            appropriateFor: nil, create: true
        )
        file = support.appendingPathComponent("guoapp/state.json")
        load()
        isLoading = false
    }

    private struct Snapshot: Codable {
        var favorites: [String: Drama]
        var followStates: [String: FollowState]
        var history: [WatchEntry]
        var settings: Settings
    }

    private func load() {
        guard let data = try? Data(contentsOf: file),
              let snap = try? JSONDecoder().decode(Snapshot.self, from: data) else { return }
        favorites = snap.favorites
        followStates = snap.followStates
        history = snap.history
        settings = snap.settings
    }

    private func save() {
        guard !isLoading else { return }
        let snap = Snapshot(favorites: favorites, followStates: followStates,
                            history: history, settings: settings)
        guard let data = try? JSONEncoder().encode(snap) else { return }
        try? FileManager.default.createDirectory(at: file.deletingLastPathComponent(),
                                                  withIntermediateDirectories: true)
        try? data.write(to: file, options: .atomic)
    }

    func isFollowed(_ key: String) -> Bool { followStates[key] != nil }

    func toggleFollow(_ drama: Drama) {
        if followStates.removeValue(forKey: drama.key) != nil {
            favorites.removeValue(forKey: drama.key)
        } else {
            var state = FollowState()
            state.knownEpisodes = drama.episodes
            state.readEpisodes = 0
            followStates[drama.key] = state
            favorites[drama.key] = drama
        }
    }

    func markWatched(_ drama: Drama, episode: Int) {
        let entry = WatchEntry(dramaKey: drama.key, title: drama.title,
                               cover: drama.cover, source: drama.source, episode: episode)
        history.removeAll { $0.id == entry.id }
        history.insert(entry, at: 0)
        if history.count > 300 { history = Array(history.prefix(300)) }
        if var state = followStates[drama.key] {
            state.readEpisodes = max(state.readEpisodes, episode)
            followStates[drama.key] = state
        }
    }

    var followedDramas: [Drama] {
        followStates.compactMap { favorites[$0.key] }
    }

    var updatedDramas: [Drama] {
        followedDramas.filter { (followStates[$0.key]?.newEpisodes ?? 0) > 0 }
    }
}
