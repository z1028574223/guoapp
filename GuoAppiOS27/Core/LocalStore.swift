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

struct Profile: Codable, Identifiable {
    var id: String
    var name: String
    var admin: Bool = false
    var sources: [String] = []
    var download: Bool = true
}

/// Local, per-device data. The Go core has no concept of users, follow state,
/// history or settings — this store reconstructs them, isolated per user.
final class LocalStore: ObservableObject {
    static let shared = LocalStore()

    @Published private(set) var profiles: [Profile] = [Profile(id: "default", name: "管理员", admin: true)]
    @Published private(set) var activeUserID = "default"
    @Published var favorites: [String: Drama] = [:] { didSet { save() } }
    @Published var followStates: [String: FollowState] = [:] { didSet { save() } }
    @Published var history: [WatchEntry] = [] { didSet { save() } }
    @Published var recentSearches: [String] = [] { didSet { save() } }
    @Published var settings = Settings() { didSet { save() } }

    private let file: URL
    private var isLoading = true

    private init() {
        let support = try! FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask,
            appropriateFor: nil, create: true)
        file = support.appendingPathComponent("guoapp/state.json")
        load()
        isLoading = false
    }

    private struct UserData: Codable {
        var favorites: [String: Drama] = [:]
        var followStates: [String: FollowState] = [:]
        var history: [WatchEntry] = []
        var recentSearches: [String] = []
        var settings = Settings()
    }

    private struct Snapshot: Codable {
        var profiles: [Profile] = [Profile(id: "default", name: "管理员", admin: true)]
        var activeUserID: String = "default"
        var users: [String: UserData] = [:]
    }

    private func load() {
        guard let data = try? Data(contentsOf: file),
              let snap = try? JSONDecoder().decode(Snapshot.self, from: data) else { return }
        profiles = snap.profiles
        activeUserID = snap.activeUserID
        applyUserData(snap.users[activeUserID] ?? UserData())
    }

    private func applyUserData(_ data: UserData) {
        favorites = data.favorites
        followStates = data.followStates
        history = data.history
        recentSearches = data.recentSearches
        settings = data.settings
    }

    private func currentUserData() -> UserData {
        UserData(favorites: favorites, followStates: followStates, history: history,
                 recentSearches: recentSearches, settings: settings)
    }

    private func save() {
        guard !isLoading else { return }
        var snap = Snapshot()
        if let data = try? Data(contentsOf: file),
           let existing = try? JSONDecoder().decode(Snapshot.self, from: data) {
            snap = existing
        }
        snap.profiles = profiles
        snap.activeUserID = activeUserID
        snap.users[activeUserID] = currentUserData()
        guard let data = try? JSONEncoder().encode(snap) else { return }
        try? FileManager.default.createDirectory(at: file.deletingLastPathComponent(),
                                                  withIntermediateDirectories: true)
        try? data.write(to: file, options: .atomic)
    }

    // MARK: - User management

    func switchUser(_ id: String) {
        guard profiles.contains(where: { $0.id == id }), id != activeUserID else { return }
        save()
        isLoading = true
        activeUserID = id
        if let data = try? Data(contentsOf: file),
           let snap = try? JSONDecoder().decode(Snapshot.self, from: data) {
            applyUserData(snap.users[id] ?? UserData())
        } else {
            applyUserData(UserData())
        }
        isLoading = false
    }

    func addUser(name: String) {
        let suffix = String(UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(8))
        profiles.append(Profile(id: "u_" + suffix, name: name))
        save()
    }

    func deleteUser(_ id: String) {
        guard id != "default", id != activeUserID else { return }
        profiles.removeAll { $0.id == id }
        save()
    }

    var currentProfile: Profile {
        profiles.first { $0.id == activeUserID } ?? Profile(id: "default", name: "管理员", admin: true)
    }

    // MARK: - Search history

    func addRecentSearch(_ query: String) {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return }
        recentSearches.removeAll { $0.caseInsensitiveCompare(q) == .orderedSame }
        recentSearches.insert(q, at: 0)
        if recentSearches.count > 20 { recentSearches = Array(recentSearches.prefix(20)) }
    }

    // MARK: - Follow / history

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

    var followedDramas: [Drama] { followStates.compactMap { favorites[$0.key] } }
    var updatedDramas: [Drama] {
        followedDramas.filter { (followStates[$0.key]?.newEpisodes ?? 0) > 0 }
    }
}
