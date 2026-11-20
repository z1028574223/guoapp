import SwiftUI

/// A site module shown in the list (installed or from the online index).
struct ModuleEntry: Identifiable {
    let id: String
    let name: String
    let version: String
    let desc: String
    let adult: Bool
    let installed: Bool
    let bundled: Bool
    let capabilities: [String]
    let hosts: [String]

    init(_ dict: [String: Any]) {
        id = dict["id"] as? String ?? ""
        name = dict["name"] as? String ?? id
        version = dict["version"] as? String ?? ""
        desc = dict["description"] as? String ?? ""
        adult = dict["adult"] as? Bool ?? false
        installed = dict["installed"] as? Bool ?? false
        bundled = dict["bundled"] as? Bool ?? false
        capabilities = dict["capabilities"] as? [String] ?? []
        hosts = dict["hosts"] as? [String] ?? []
    }
}

/// Station module manager: installed / online index / bundled tabs.
/// Mirrors guoapp's ModulesPage, using the Go core's module actions.
struct ModulesView: View {
    @EnvironmentObject var store: LocalStore
    @State private var tab = 0
    @State private var installed: [ModuleEntry] = []
    @State private var online: [ModuleEntry] = []
    @State private var loading = false
    @State private var status: String?
    @State private var pendingInstall: ModuleEntry?
    @State private var refreshID = UUID()

    private let tabs = ["已安装", "在线仓库"]

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $tab) {
                ForEach(0..<tabs.count, id: \.self) { Text(tabs[$0]).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal).padding(.vertical, 8)

            if let status {
                Text(status).font(.caption).foregroundStyle(GlassTokens.accent)
                    .padding(.horizontal).padding(.bottom, 6)
            }

            ScrollView {
                if loading {
                    ProgressView().padding(.top, 40)
                } else if tab == 0 {
                    moduleList(installed, installedTab: true)
                } else {
                    moduleList(online, installedTab: false)
                }
            }
            .refreshable { await reload() }
        }
        .navigationTitle("站源模块")
        .navigationBarTitleDisplayMode(.inline)
        .task { await reload() }
        .alert("安装站源", isPresented: Binding(
            get: { pendingInstall != nil },
            set: { if !$0 { pendingInstall = nil } }
        )) {
            Button("取消", role: .cancel) { pendingInstall = nil }
            Button("安装") {
                if let m = pendingInstall { Task { await install(m) } }
            }
        } message: {
            if let m = pendingInstall {
                Text("「\(m.name)」将访问以下域名：\n\(m.hosts.joined(separator: "、"))\n\n功能：\(m.capabilities.joined(separator: "、"))\(m.adult ? "\n\n⚠️ 限制级内容" : "")")
            }
        }
    }

    @ViewBuilder
    private func moduleList(_ modules: [ModuleEntry], installedTab: Bool) -> some View {
        if modules.isEmpty {
            VStack(spacing: 10) {
                Image(systemName: "puzzlepiece").font(.system(size: 40)).foregroundStyle(.tertiary)
                Text(installedTab ? "还没有安装站源" : "在线仓库暂无内容")
                    .font(.subheadline).foregroundStyle(.secondary)
                if installedTab {
                    Button("去在线仓库看看") { tab = 1 }
                        .font(.caption).foregroundStyle(GlassTokens.accent)
                }
            }.padding(.top, 60)
        } else {
            LazyVStack(spacing: 12) {
                ForEach(modules) { module in
                    moduleCard(module, installedTab: installedTab)
                }
            }.padding()
        }
    }

    private func moduleCard(_ module: ModuleEntry, installedTab: Bool) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: module.adult ? "exclamationmark.triangle.fill" : "puzzlepiece.fill")
                .font(.title2).foregroundStyle(module.adult ? .orange : GlassTokens.accent)
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(module.name).font(.subheadline.bold())
                    if module.bundled {
                        Text("内置").font(.caption2).padding(.horizontal, 6).padding(.vertical, 2)
                            .background(.thinMaterial, in: Capsule())
                    }
                    if module.adult {
                        Text("限制级").font(.caption2.bold()).foregroundStyle(.white)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(.orange, in: Capsule())
                    }
                }
                Text(module.desc).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                Text("v\(module.version) · \(module.id)")
                    .font(.caption2).foregroundStyle(.tertiary)
                if !module.capabilities.isEmpty {
                    Text(module.capabilities.joined(separator: " · "))
                        .font(.caption2).foregroundStyle(.tertiary).lineLimit(1)
                }
            }
            Spacer()
            if installedTab {
                Button(role: .destructive) {
                    Task { await uninstall(module) }
                } label: {
                    Image(systemName: "trash").font(.subheadline)
                }.buttonStyle(.glass)
            } else if module.installed {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
            } else {
                Button { pendingInstall = module } label: {
                    Text("安装").font(.caption.bold())
                        .padding(.horizontal, 14).padding(.vertical, 7)
                }
                .buttonStyle(.glassProminent)
            }
        }
        .padding(14)
        .adaptiveGlass(level: store.settings.glassLevel,
                       in: AnyShape(RoundedRectangle(cornerRadius: GlassTokens.cornerMedium)))
    }

    func reload() async {
        loading = true
        defer { loading = false }
        do {
            let inst = try await Repository.shared.modules()
            installed = inst.map { ModuleEntry($0) }
            let index = try await Repository.shared.moduleIndex()
            let items = index["items"] as? [[String: Any]] ?? []
            online = items.map { ModuleEntry($0) }
            // Mark already-installed ones
            let installedIDs = Set(installed.map { $0.id })
            online = online.map { m in
                let d: [String: Any] = ["id": m.id, "name": m.name, "version": m.version,
                                        "description": m.desc, "adult": m.adult,
                                        "bundled": m.bundled, "capabilities": m.capabilities,
                                        "hosts": m.hosts, "installed": installedIDs.contains(m.id)]
                return ModuleEntry(d)
            }
        } catch {
            status = "加载失败：\(error.localizedDescription)"
        }
    }

    func install(_ module: ModuleEntry) async {
        status = "正在准备 \(module.name)…"
        do {
            let prepared = try await Repository.shared.prepareModule(
                indexed: module.id, bundled: module.bundled)
            if let error = prepared["error"] as? String, !error.isEmpty {
                status = "准备失败：\(error)"
                return
            }
            guard let token = prepared["token"] as? String, !token.isEmpty else {
                status = "准备失败：未返回安装凭证"
                return
            }
            status = "正在安装 \(module.name)…"
            try await Repository.shared.installModule(token: token)
            status = "已安装 \(module.name)"
            await reload()
        } catch {
            status = "安装失败：\(error.localizedDescription)"
        }
    }

    func uninstall(_ module: ModuleEntry) async {
        status = "正在卸载 \(module.name)…"
        do {
            try await Repository.shared.uninstallModule(source: module.id)
            status = "已卸载 \(module.name)"
            await reload()
        } catch {
            status = "卸载失败：\(error.localizedDescription)"
        }
    }
}
