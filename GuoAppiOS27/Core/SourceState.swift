import Foundation
import Combine

/// Shared list of available site sources (id + name), loaded from the Go core
/// after initialize. Discover/Search/Detail all read from this single object.
final class SourceState: ObservableObject {
    static let shared = SourceState()

    struct Source: Identifiable, Hashable {
        let id: String
        let name: String
    }

    @Published private(set) var sources: [Source] = []
    @Published private(set) var activeID = ""

    private init() {}

    func load(_ raw: [[String: Any]]) {
        let parsed = raw.compactMap { dict -> Source? in
            guard let id = dict["id"] as? String, !id.isEmpty else { return nil }
            let name = dict["name"] as? String ?? id
            return Source(id: id, name: name)
        }
        // De-duplicate by id, prefer non-empty names
        var seen = Set<String>()
        let unique = parsed.filter { seen.insert($0.id).inserted }
        sources = unique
        if activeID.isEmpty || !unique.contains(where: { $0.id == activeID }) {
            // Prefer hongguo if present, else first available.
            activeID = unique.first { $0.id == "hongguo" }?.id ?? unique.first?.id ?? ""
        }
    }

    func name(of id: String) -> String {
        sources.first { $0.id == id }?.name ?? id
    }

    func select(_ id: String) { activeID = id }
}
