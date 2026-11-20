import SwiftUI

/// Settings: resource/proxy, storage/cache, playback, about.
struct SettingsView: View {
    @EnvironmentObject var store: LocalStore
    @State private var settings: [String: Any] = [:]
    @State private var storage: [String: Any] = [:]
    @State private var cacheBytes: Int64 = 0
    @State private var proxyMode = "auto"
    @State private var proxyUrl = ""
    @State private var status: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                StatusBanner(text: status)

                // Appearance / liquid glass
                SectionCard(title: "外观", icon: "paintbrush.fill") {
                    HStack {
                        Text("液态玻璃通透度").font(.subheadline)
                        Spacer()
                        Text("\(Int(store.settings.glassLevel * 100))%")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Slider(value: $store.settings.glassLevel, in: 0...1)
                }

                // Playback
                SectionCard(title: "播放", icon: "play.circle.fill") {
                    HStack {
                        Text("默认倍速").font(.subheadline)
                        Spacer()
                        Picker("", selection: $store.settings.playbackSpeed) {
                            ForEach([0.5, 0.75, 1.0, 1.25, 1.5, 2.0], id: \.self) { s in
                                Text("\(s, specifier: "%.2g")x").tag(s)
                            }
                        }.pickerStyle(.segmented).frame(width: 220)
                    }
                    Toggle("默认开启弹幕", isOn: $store.settings.danmakuEnabled)
                        .font(.subheadline)
                }

                // Network / proxy
                SectionCard(title: "网络与代理", icon: "network") {
                    Picker("连接方式", selection: $proxyMode) {
                        Text("自动").tag("auto")
                        Text("直连").tag("direct")
                        Text("手动代理").tag("manual")
                    }.pickerStyle(.segmented)
                    if proxyMode == "manual" {
                        TextField("http://host:port", text: $proxyUrl)
                            .textFieldStyle(.roundedBorder)
                            .autocapitalization(.none).disableAutocorrection(true)
                    }
                    Button("保存代理设置") { Task { await saveProxy() } }
                        .font(.caption).foregroundStyle(GlassTokens.accent)
                }

                // Storage / cache
                SectionCard(title: "存储与缓存", icon: "internaldrive.fill") {
                    HStack { Text("缓存占用"); Spacer()
                        Text(formatBytes(cacheBytes)).font(.caption).foregroundStyle(.secondary) }
                    if let dir = storage["directory"] as? String {
                        HStack { Text("数据目录"); Spacer()
                            Text(dir).font(.caption2).foregroundStyle(.tertiary).lineLimit(1) }
                    }
                    HStack(spacing: 10) {
                        Button("清理缓存") { Task { await clearCache() } }
                            .font(.caption)
                        Button("刷新统计") { Task { await reload() } }
                            .font(.caption)
                    }
                }

                // About
                SectionCard(title: "关于", icon: "info.circle.fill") {
                    HStack { Text("版本"); Spacer(); Text("1.0.0").foregroundStyle(.secondary) }
                    HStack { Text("最低系统"); Spacer(); Text("iOS 26+").foregroundStyle(.secondary) }
                    Text("原生 SwiftUI 界面 · 复用 guoapp Go 核心 · iOS 27 液态玻璃")
                        .font(.caption2).foregroundStyle(.tertiary)
                }
            }.padding(.top, 8)
        }
        .navigationTitle("设置")
        .navigationBarTitleDisplayMode(.inline)
        .task { await reload() }
    }

    func reload() async {
        do {
            settings = try await Repository.shared.resourceSettings()
            proxyMode = settings["proxyMode"] as? String ?? "auto"
            proxyUrl = settings["proxyUrl"] as? String ?? ""
            storage = try await Repository.shared.storage()
            cacheBytes = await (try? Repository.shared.cacheBytes()) ?? 0
        } catch { status = "加载失败：\(error.localizedDescription)" }
    }

    func saveProxy() async {
        do {
            let saved = try await Repository.shared.saveResourceSettings([
                "proxyMode": proxyMode, "proxyUrl": proxyUrl
            ])
            settings = saved
            status = "代理设置已保存"
        } catch { status = "保存失败：\(error.localizedDescription)" }
    }

    func clearCache() async {
        do {
            try await Repository.shared.clearCache()
            cacheBytes = await (try? Repository.shared.cacheBytes()) ?? 0
            status = "缓存已清理"
        } catch { status = "清理失败：\(error.localizedDescription)" }
    }

    private func formatBytes(_ b: Int64) -> String {
        if b < 1024 * 1024 { return String(format: "%.1fKB", Double(b) / 1024) }
        return String(format: "%.1fMB", Double(b) / 1024 / 1024)
    }
}

struct StatusBanner: View {
    let text: String?
    var body: some View {
        if let text, !text.isEmpty {
            Text(text).font(.caption).foregroundStyle(GlassTokens.accent)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct SectionCard<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon).foregroundStyle(GlassTokens.accent)
                Text(title).font(.headline)
            }
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: GlassTokens.cornerMedium))
    }
}
