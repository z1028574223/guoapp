import SwiftUI

/// Batch episode picker that enqueues downloads via the Go core.
struct DownloadPicker: View {
    @EnvironmentObject var store: LocalStore
    let chapters: [Chapter]
    let drama: Drama
    @Binding var status: String?
    @Environment(\.dismiss) private var dismiss
    @State private var selected: Set<Int> = []
    @State private var quality = 0
    @State private var busy = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                if let status, !status.isEmpty {
                    Text(status).font(.caption).foregroundStyle(GlassTokens.accent)
                        .padding(.horizontal)
                }
                HStack {
                    Text("选择要下载的剧集").font(.headline)
                    Spacer()
                    Button("全选") { selected = Set(chapters.indices) }
                        .font(.caption)
                    Button("清空") { selected = [] }
                        .font(.caption)
                }.padding(.horizontal)

                ScrollView {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 10) {
                        ForEach(Array(chapters.enumerated()), id: \.offset) { idx, chapter in
                            Button {
                                if selected.contains(idx) { selected.remove(idx) }
                                else { selected.insert(idx) }
                            } label: {
                                Text(chapter.title.isEmpty ? "第\(idx + 1)集" : chapter.title)
                                    .font(.caption).lineLimit(1)
                                    .frame(maxWidth: .infinity, minHeight: 40)
                            }
                            .adaptiveGlass(level: selected.contains(idx) ? 0.9 : store.settings.glassLevel,
                                           in: AnyShape(RoundedRectangle(cornerRadius: 10)), interactive: true)
                            .foregroundStyle(selected.contains(idx) ? Color.primary : .secondary)
                        }
                    }.padding(.horizontal)
                }

                HStack {
                    Text("清晰度").font(.subheadline)
                    Spacer()
                    Picker("", selection: $quality) {
                        Text("自动").tag(0)
                        Text("高清").tag(1)
                        Text("超清").tag(2)
                    }.pickerStyle(.segmented).frame(width: 200)
                }.padding(.horizontal)

                Button {
                    Task { await download() }
                } label: {
                    HStack {
                        if busy { ProgressView().tint(.white) }
                        Text(busy ? "添加中…" : "下载 \(selected.count) 集")
                            .font(.headline)
                    }.frame(maxWidth: .infinity, minHeight: 48)
                        .foregroundStyle(.white)
                        .background(LinearGradient(colors: [.orange, .pink],
                                                   startPoint: .topLeading, endPoint: .bottomTrailing))
                        .clipShape(Capsule())
                }
                .disabled(selected.isEmpty || busy)
                .padding(.horizontal).padding(.bottom)
            }.padding(.top)
            .navigationTitle("下载剧集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }

    func download() async {
        guard !selected.isEmpty else { return }
        busy = true
        defer { busy = false }
        let picked = selected.sorted().compactMap { idx -> (Chapter, Int)? in
            guard idx < chapters.count else { return nil }
            return (chapters[idx], idx + 1)
        }
        do {
            let added = try await Repository.shared.enqueueDownloads(
                drama: drama, chapters: picked, quality: quality)
            status = "已添加 \(added) 个下载任务"
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { dismiss() }
        } catch {
            status = "添加失败：\(error.localizedDescription)"
        }
    }
}
