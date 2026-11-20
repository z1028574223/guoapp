import SwiftUI

/// Local multi-user management (Go core has no user concept; data is per-device).
struct UsersView: View {
    @EnvironmentObject var store: LocalStore
    @State private var newName = ""
    @State private var showAdd = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("多用户").font(.largeTitle.bold()).padding(.horizontal)

                Text("每个用户独立保存追剧、观看记录和偏好设置。轻点即可切换。")
                    .font(.caption).foregroundStyle(.secondary).padding(.horizontal)

                VStack(spacing: 10) {
                    ForEach(store.profiles) { profile in
                        HStack(spacing: 12) {
                            Image(systemName: profile.id == store.activeUserID
                                  ? "person.crop.circle.fill.badge.checkmark"
                                  : "person.crop.circle")
                                .font(.title2)
                                .foregroundStyle(profile.id == store.activeUserID ? GlassTokens.accent : .secondary)
                            VStack(alignment: .leading) {
                                Text(profile.name).font(.subheadline.weight(.semibold))
                                HStack {
                                    if profile.admin { Text("管理员") }
                                    if !profile.sources.isEmpty {
                                        Text("站源：\(profile.sources.count)")
                                    }
                                }.font(.caption2).foregroundStyle(.tertiary)
                            }
                            Spacer()
                            if profile.id == store.activeUserID {
                                Image(systemName: "checkmark").foregroundStyle(GlassTokens.accent)
                            } else {
                                Button("切换") { store.switchUser(profile.id) }
                                    .font(.caption).buttonStyle(.borderless)
                            }
                            if !profile.admin && store.profiles.count > 1 {
                                Button(role: .destructive) { store.deleteUser(profile.id) } label: {
                                    Image(systemName: "trash").font(.caption)
                                }.buttonStyle(.borderless)
                            }
                        }
                        .padding(14)
                        .adaptiveGlass(level: store.settings.glassLevel,
                                       in: AnyShape(RoundedRectangle(cornerRadius: GlassTokens.cornerMedium)))
                    }
                }.padding(.horizontal)

                if showAdd {
                    HStack {
                        TextField("用户名称", text: $newName)
                            .textFieldStyle(.roundedBorder)
                        Button("添加") {
                            if !newName.isEmpty {
                                store.addUser(name: newName)
                                newName = ""
                                showAdd = false
                            }
                        }.buttonStyle(.glassProminent)
                        Button("取消") { showAdd = false; newName = "" }
                            .buttonStyle(.borderless)
                    }.padding(.horizontal)
                } else {
                    Button { showAdd = true } label: {
                        Label("添加用户", systemImage: "person.badge.plus")
                    }.buttonStyle(.glass).padding(.horizontal)
                }
            }.padding(.top, 8)
        }
        .navigationTitle("用户")
        .navigationBarTitleDisplayMode(.inline)
    }
}
