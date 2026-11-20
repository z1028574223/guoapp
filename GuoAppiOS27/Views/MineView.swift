import SwiftUI

struct MineView: View {
    @EnvironmentObject var store: LocalStore
    @EnvironmentObject var sources: SourceState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("我的").font(.largeTitle.bold()).padding(.horizontal)

                NavigationLink {
                    UsersView()
                } label: {
                    HStack(spacing: 13) {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 48)).foregroundStyle(GlassTokens.accent)
                        VStack(alignment: .leading) {
                            Text(store.currentProfile.name).font(.headline).foregroundStyle(.primary)
                            Text(store.currentProfile.admin ? "管理员" : "普通用户")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").foregroundStyle(.tertiary)
                    }
                    .padding()
                    .adaptiveGlass(level: store.settings.glassLevel,
                                   in: AnyShape(RoundedRectangle(cornerRadius: GlassTokens.cornerLarge)))
                }
                .buttonStyle(.plain).padding(.horizontal)

                HStack {
                    StatCell(value: "\(store.followedDramas.count)", label: "追剧")
                    Divider().frame(height: 30)
                    StatCell(value: "\(store.history.count)", label: "观看记录")
                    Divider().frame(height: 30)
                    StatCell(value: "\(sources.sources.count)", label: "可用站源")
                }
                .padding()
                .adaptiveGlass(level: store.settings.glassLevel,
                               in: AnyShape(RoundedRectangle(cornerRadius: GlassTokens.cornerMedium)))
                .padding(.horizontal)

                // iOS 27 transparency slider
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "sparkles").foregroundStyle(GlassTokens.accentHot)
                        Text("液态玻璃").font(.headline)
                        Text("iOS 27").font(.caption2.bold()).foregroundStyle(.white)
                            .padding(.horizontal, 7).padding(.vertical, 3)
                            .background(LinearGradient(colors: [.purple, .orange],
                                                       startPoint: .topLeading, endPoint: .bottomTrailing))
                            .clipShape(Capsule())
                    }
                    Text("调节玻璃材质的通透程度，全 App 实时生效。")
                        .font(.caption).foregroundStyle(.secondary)
                    HStack {
                        Text("超清晰").font(.caption2).foregroundStyle(.tertiary)
                        Slider(value: $store.settings.glassLevel, in: 0...1)
                        Text("着色").font(.caption2).foregroundStyle(.tertiary)
                    }
                    Text(levelLabel(store.settings.glassLevel))
                        .font(.caption.bold()).foregroundStyle(GlassTokens.accent)
                        .frame(maxWidth: .infinity)
                }
                .padding()
                .adaptiveGlass(level: store.settings.glassLevel,
                               in: AnyShape(RoundedRectangle(cornerRadius: GlassTokens.cornerLarge)))
                .padding(.horizontal)

                // Feature entries
                VStack(spacing: 0) {
                    NavRow(icon: "square.and.arrow.down.fill", title: "下载管理") { DownloadsView() }
                    Divider().padding(.leading, 50)
                    NavRow(icon: "puzzlepiece.fill", title: "站源模块") { ModulesView() }
                    Divider().padding(.leading, 50)
                    NavRow(icon: "gearshape.fill", title: "设置") { SettingsView() }
                    Divider().padding(.leading, 50)
                    NavRow(icon: "person.2.fill", title: "多用户") { UsersView() }
                }
                .padding(.vertical, 6)
                .adaptiveGlass(level: store.settings.glassLevel,
                               in: AnyShape(RoundedRectangle(cornerRadius: GlassTokens.cornerLarge)))
                .padding(.horizontal)

                Text("原生 SwiftUI · 复用 guoapp Go 核心 · iOS 27 液态玻璃")
                    .font(.caption2).foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity).padding(.bottom)
            }
        }
    }

    private func levelLabel(_ v: Double) -> String {
        if v < 0.25 { return "通透 \(Int(v * 100))% · 超清晰" }
        if v < 0.6 { return "通透 \(Int(v * 100))% · 均衡" }
        if v < 0.85 { return "通透 \(Int(v * 100))% · 柔和" }
        return "通透 \(Int(v * 100))% · 完全着色"
    }
}

struct StatCell: View {
    let value: String
    let label: String
    var body: some View {
        VStack(spacing: 3) {
            Text(value).font(.title2.bold())
            Text(label).font(.caption).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity)
    }
}

struct NavRow<Destination: View>: View {
    let icon: String
    let title: String
    @ViewBuilder let destination: Destination
    var body: some View {
        NavigationLink {
            destination
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon).foregroundStyle(GlassTokens.accent).frame(width: 26)
                Text(title).font(.subheadline).foregroundStyle(.primary)
                Spacer()
                Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.tertiary)
            }
            .padding(.horizontal).padding(.vertical, 11)
        }.buttonStyle(.plain)
    }
}
