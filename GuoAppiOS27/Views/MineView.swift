import SwiftUI

struct MineView: View {
    @EnvironmentObject var store: LocalStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("我的").font(.largeTitle.bold()).padding(.horizontal)

                // User card
                HStack(spacing: 13) {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 48)).foregroundStyle(GlassTokens.accent)
                    VStack(alignment: .leading) {
                        Text("管理员").font(.headline)
                        Text("本机单用户模式").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("切换").font(.caption).padding(.horizontal, 12).padding(.vertical, 7)
                        .adaptiveGlass(level: store.settings.glassLevel,
                                       in: AnyShape(Capsule()), interactive: true)
                }
                .padding()
                .adaptiveGlass(level: store.settings.glassLevel,
                               in: AnyShape(RoundedRectangle(cornerRadius: GlassTokens.cornerLarge)))
                .padding(.horizontal)

                // Stats
                HStack {
                    StatCell(value: "\(store.followedDramas.count)", label: "追剧")
                    Divider().frame(height: 30)
                    StatCell(value: "\(store.history.count)", label: "观看记录")
                    Divider().frame(height: 30)
                    StatCell(value: "0", label: "已下载")
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
                    Text("调节玻璃材质的通透程度，从「超清晰」到「完全着色」。全 App 实时生效。")
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

                // Settings list
                VStack(spacing: 0) {
                    SettingRow(icon: "moon.circle.fill", title: "外观", value: "跟随系统")
                    Divider().padding(.leading, 50)
                    SettingRow(icon: "play.circle.fill", title: "播放", value: "\(Int(store.settings.playbackSpeed))倍速")
                    Divider().padding(.leading, 50)
                    SettingRow(icon: "square.and.arrow.down.fill", title: "下载与存储", value: "")
                    Divider().padding(.leading, 50)
                    SettingRow(icon: "puzzlepiece.fill", title: "站源模块", value: "")
                    Divider().padding(.leading, 50)
                    SettingRow(icon: "info.circle.fill", title: "关于", value: "v1.0.0")
                }
                .padding(.vertical, 6)
                .adaptiveGlass(level: store.settings.glassLevel,
                               in: AnyShape(RoundedRectangle(cornerRadius: GlassTokens.cornerLarge)))
                .padding(.horizontal)

                Text("界面为 iOS 液态玻璃概念稿，功能复用 guoapp 的 Go 核心。")
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
        }
        .frame(maxWidth: .infinity)
    }
}

struct SettingRow: View {
    let icon: String
    let title: String
    let value: String
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon).foregroundStyle(GlassTokens.accent)
                .frame(width: 26)
            Text(title).font(.subheadline)
            Spacer()
            Text(value).font(.caption).foregroundStyle(.secondary)
            Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.tertiary)
        }
        .padding(.horizontal).padding(.vertical, 11)
    }
}
