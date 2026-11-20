import SwiftUI

/// Watch history grouped by date (today / yesterday / earlier).
struct HistoryView: View {
    @EnvironmentObject var store: LocalStore
    @State private var query = ""
    @State private var route: Drama?

    private var filtered: [WatchEntry] {
        let q = query.trimmingCharacters(in: .whitespaces)
        return q.isEmpty ? store.history : store.history.filter { $0.title.localizedCaseInsensitiveContains(q) }
    }

    private var grouped: [(String, [WatchEntry])] {
        let cal = Calendar.current
        let now = Date()
        var today: [WatchEntry] = []
        var yesterday: [WatchEntry] = []
        var earlier: [WatchEntry] = []
        for e in filtered {
            if cal.isDateInToday(e.updatedAt) { today.append(e) }
            else if cal.isDateInYesterday(e.updatedAt) { yesterday.append(e) }
            else { earlier.append(e) }
        }
        var result: [(String, [WatchEntry])] = []
        if !today.isEmpty { result.append(("今天", today)) }
        if !yesterday.isEmpty { result.append(("昨天", yesterday)) }
        if !earlier.isEmpty { result.append(("更早", earlier)) }
        return result
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("搜索观看记录", text: $query).textFieldStyle(.plain)
                if !store.history.isEmpty {
                    Button("清空") { store.history = [] }
                        .font(.caption).foregroundStyle(.red)
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 11)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal).padding(.top, 6)

            ScrollView {
                if filtered.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "clock.arrow.circlepath").font(.system(size: 40)).foregroundStyle(.tertiary)
                        Text("还没有观看记录").font(.subheadline).foregroundStyle(.secondary)
                    }.padding(.top, 60)
                } else {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        ForEach(grouped, id: \.0) { title, entries in
                            Section(header: Text(title).font(.caption.bold()).foregroundStyle(.secondary)) {
                                ForEach(entries) { entry in
                                    HistoryRow(entry: entry) {
                                        if let drama = store.favorites[entry.dramaKey] { route = drama }
                                    }
                                }
                            }
                        }
                    }.padding()
                }
            }
        }
        .navigationTitle("观看记录")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $route) { drama in DetailView(drama: drama) }
    }
}

struct HistoryRow: View {
    let entry: WatchEntry
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                AsyncCover(cover: entry.cover, level: 0.3)
                    .frame(width: 52, height: 72).clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                VStack(alignment: .leading, spacing: 5) {
                    Text(entry.title).font(.subheadline.weight(.semibold)).lineLimit(1)
                    Text("看到第 \(entry.episode) 集").font(.caption).foregroundStyle(.secondary)
                    Text(entry.source).font(.caption2).foregroundStyle(.tertiary)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.tertiary)
            }
            .padding(10)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
        }.buttonStyle(.plain)
    }
}
