import SwiftUI

@main
struct GuoAppiOS27App: App {
    @StateObject private var store = LocalStore.shared
    @StateObject private var sources = SourceState.shared
    @State private var ready = false
    @State private var bootError: String?

    var body: some Scene {
        WindowGroup {
            ZStack {
                if ready {
                    RootTabView()
                        .environmentObject(store)
                        .environmentObject(sources)
                } else {
                    BootView(error: $bootError)
                }
            }
            .task {
                do {
                    try await Repository.shared.initialize()
                    let list = try await Repository.shared.bootstrapSources()
                    sources.load(list)
                    ready = true
                } catch {
                    // Still allow the UI to open if the core fails to initialize.
                    bootError = error.localizedDescription
                    ready = true
                }
            }
        }
    }
}

struct BootView: View {
    @Binding var error: String?
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 18) {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(GlassTokens.accent)
                Text("小果影视").font(.title.bold()).foregroundStyle(.white)
                if let error {
                    Text("核心初始化：\(error)")
                        .font(.caption).foregroundStyle(.white.opacity(0.6))
                        .multilineTextAlignment(.center).padding(.horizontal)
                } else {
                    ProgressView().tint(.white)
                }
            }
        }
    }
}
