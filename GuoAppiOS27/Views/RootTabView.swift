import SwiftUI

struct RootTabView: View {
    @EnvironmentObject var store: LocalStore
    @EnvironmentObject var sources: SourceState
    @State private var selection = 0

    var body: some View {
        TabView(selection: $selection) {
            Tab("发现", systemImage: "compass.canvas.fill", value: 0) {
                NavigationStack { DiscoverView() }
            }
            Tab("追剧", systemImage: "bookmark.fill", value: 1) {
                NavigationStack { FollowView() }
            }
            Tab("历史", systemImage: "clock.arrow.circlepath", value: 2) {
                NavigationStack { HistoryView() }
            }
            Tab("我的", systemImage: "person.fill", value: 3) {
                NavigationStack { MineView() }
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        .tint(GlassTokens.accent)
    }
}
