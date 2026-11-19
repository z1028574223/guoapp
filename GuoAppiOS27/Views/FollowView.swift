import SwiftUI

struct FollowView: View {
    @EnvironmentObject var store: LocalStore
    @State private var mode = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("追剧").font(.largeTitle.bold()).padding(.horizontal)
            Picker("筛选", selection: $mode) {
                Text("有更新 \(store.updatedDramas.count)").tag(0)
                Text("全部 \(store.followedDramas.count)").tag(1)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            let list = mode == 0 ? store.updatedDramas : store.followedDramas
            if list.isEmpty {
                ContentUnavailableView {
                    Label("还没有追剧", systemImage: "bookmark")
                } description: {
                    Text("在发现页打开一部剧，点「+」即可加入追剧。")
                }
            } else {
                List {
                    ForEach(list, id: \.key) { drama in
                        NavigationLink {
                            DetailView(drama: drama)
                        } label: {
                            FollowRow(drama: drama,
                                      state: store.followStates[drama.key],
                                      level: store.settings.glassLevel)
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
    }
}

struct FollowRow: View {
    let drama: Drama
    let state: FollowState?
    let level: Double

    var body: some View {
        HStack(spacing: 12) {
            Image(drama.cover).resizable().scaledToFill()
                .frame(width: 60, height: 82).clipped()
                .clipShape(RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 6) {
                Text(drama.title).font(.subheadline.bold())
                Text("看到第 \(state?.readEpisodes ?? 0) 集 · 共 \(drama.episodes) 集")
                    .font(.caption).foregroundStyle(.secondary)
                if let n = state?.newEpisodes, n > 0 {
                    Text("更新 \(n) 集").font(.caption2.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .adaptiveGlass(level: 0.9, in: AnyShape(Capsule()))
                }
            }
        }
        .padding(.vertical, 4)
    }
}
