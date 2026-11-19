import SwiftUI

struct RootTabView: View {
    @EnvironmentObject var store: LocalStore
    @State private var selection = 0
    @State private var path = NavigationPath()

    var body: some View {
        TabView(selection: $selection) {
            Tab("发现", systemImage: "compass.canvas.fill", value: 0) {
                NavigationStack(path: $path) { DiscoverView() }
            }
            Tab("追剧", systemImage: "bookmark.fill", value: 1) {
                NavigationStack { FollowView() }
            }
            Tab("我的", systemImage: "person.fill", value: 2) {
                NavigationStack { MineView() }
            }
        }
        // iOS 27: collapse the glass tab bar as content scrolls, keeping more
        // of the drama artwork visible while it stays reachable.
        .tabBarMinimizeBehavior(.onScrollDown)
        .tint(GlassTokens.accent)
    }
}
