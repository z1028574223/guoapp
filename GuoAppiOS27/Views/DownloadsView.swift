import SwiftUI

/// A download job reported by the Go core.
struct DownloadItem: Identifiable {
    let id: String
    let title: String
    let source: String
    let state: String
    let progress: Double
    let bytes: Int64
    let total: Int64
    let quality: Int
    let error: String?

    init(_ dict: [String: Any]) {
        id = dict["id"] as? String ?? UUID().uuidString
        let drama = dict["drama"] as? [String: Any] ?? [:]
        title = drama["title"] as? String ?? "未知"
        source = drama["source"] as? String ?? ""
        state = dict["state"] as? String ?? "queued"
        progress = dict["progress"] as? Double ?? 0
        bytes = dict["bytes"] as? Int64 ?? 0
        total = dict["total"] as? Int64 ?? 0
        quality = dict["quality"] as? Int ?? 0
        error = dict["error"] as? String
    }

    var stateLabel: String {
        switch state {
        case "queued": return "排队中"
        case "downloading": return "下载中"
        case "paused": return "已暂停"
        case "completed": return "已完成"
        case "converting": return "转码中"
        case "failed": return "失败"
        case "removing": return "移除中"
        default: return state
        }
    }
}

struct DownloadsView: View {
    @EnvironmentObject var store: LocalStore
    @State private var jobs: [DownloadItem] = []
    @State private var loading = true
    @State private var status: String?
    @State private var directory = ""

    var body: some View {
        VStack(spacing: 0) {
            if let status {
                Text(status).font(.caption).foregroundStyle(GlassTokens.accent).padding(.vertical, 6)
            }
            ScrollView {
                if loading {
                    ProgressView().padding(.top, 40)
                } else if jobs.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "square.and.arrow.down").font(.system(size: 40)).foregroundStyle(.tertiary)
                        Text("还没有下载任务").font(.subheadline).foregroundStyle(.secondary)
                        Text("在剧集详情或播放页选择「下载」添加")
                            .font(.caption).foregroundStyle(.tertiary)
                    }.padding(.top, 60)
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(jobs) { job in jobCard(job) }
                    }.padding()
                }
            }
            .refreshable { await reload() }

            HStack {
                Image(systemName: "folder").font(.caption).foregroundStyle(.tertiary)
                Text(directory.isEmpty ? "下载目录加载中" : directory)
                    .font(.caption2).foregroundStyle(.tertiary).lineLimit(1)
            }.padding(.horizontal).padding(.bottom, 8)
        }
        .navigationTitle("下载")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { Task { await controlAll() } } label: {
                    Image(systemName: "pause.circle")
                }
            }
        }
        .task { await reload() }
    }

    private func jobCard(_ job: DownloadItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: stateIcon(job.state)).foregroundStyle(stateColor(job.state))
                Text(job.title).font(.subheadline.weight(.semibold)).lineLimit(1)
                Spacer()
                Text(job.stateLabel).font(.caption2).foregroundStyle(.secondary)
            }
            ProgressView(value: job.progress)
                .tint(GlassTokens.accent)
            HStack {
                Text("\(Int(job.progress * 100))%").font(.caption2).foregroundStyle(.tertiary)
                Spacer()
                if let err = job.error, !err.isEmpty {
                    Text(err).font(.caption2).foregroundStyle(.red).lineLimit(1)
                } else if job.total > 0 {
                    Text("\(formatBytes(job.bytes)) / \(formatBytes(job.total))")
                        .font(.caption2).foregroundStyle(.tertiary)
                }
            }
            HStack(spacing: 8) {
                if job.state == "downloading" || job.state == "queued" {
                    Button("暂停") { Task { await control(job.id, "pause") } }
                        .font(.caption2)
                } else if job.state == "paused" {
                    Button("继续") { Task { await control(job.id, "resume") } }
                        .font(.caption2)
                }
                Button("移除") { Task { await control(job.id, "remove") } }
                    .font(.caption2).foregroundStyle(.red)
            }
            .buttonStyle(.borderless)
        }
        .padding(14)
        .adaptiveGlass(level: store.settings.glassLevel,
                       in: AnyShape(RoundedRectangle(cornerRadius: GlassTokens.cornerMedium)))
    }

    func reload() async {
        loading = true
        defer { loading = false }
        do {
            let snapshot = try await Repository.shared.downloads(since: "")
            let raw = snapshot["jobs"] as? [[String: Any]] ?? []
            jobs = raw.map { DownloadItem($0) }
            directory = await (try? Repository.shared.downloadDirectory()) ?? ""
        } catch {
            status = "加载失败：\(error.localizedDescription)"
        }
    }

    func control(_ id: String, _ command: String) async {
        do {
            try await Repository.shared.controlDownloads(jobId: id, command: command)
            await reload()
        } catch { status = "操作失败：\(error.localizedDescription)" }
    }

    func controlAll() async {
        do {
            try await Repository.shared.controlDownloads(jobId: "", command: "pauseAll")
            await reload()
        } catch { status = "操作失败：\(error.localizedDescription)" }
    }

    private func stateIcon(_ state: String) -> String {
        switch state {
        case "completed": return "checkmark.circle.fill"
        case "failed": return "exclamationmark.circle.fill"
        case "downloading": return "arrow.down.circle.fill"
        case "paused": return "pause.circle.fill"
        default: return "clock.circle.fill"
        }
    }
    private func stateColor(_ state: String) -> Color {
        switch state {
        case "completed": return .green
        case "failed": return .red
        case "downloading": return GlassTokens.accent
        default: return .secondary
        }
    }
    private func formatBytes(_ b: Int64) -> String {
        if b < 1024 { return "\(b)B" }
        if b < 1024 * 1024 { return String(format: "%.1fKB", Double(b) / 1024) }
        return String(format: "%.1fMB", Double(b) / 1024 / 1024)
    }
}
