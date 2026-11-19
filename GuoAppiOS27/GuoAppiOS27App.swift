import SwiftUI

@main
struct GuoAppiOS27App: App {
    @StateObject private var store = LocalStore.shared
    @State private var ready = false
    @State private var bootError: String?

    var body: some Scene {
        WindowGroup {
            ZStack {
                if ready {
                    RootTabView()
                        .environmentObject(store)
                } else {
                    BootView(error: $bootError)
                }
            }
            .task {
                do {
                    try await Repository.shared.initialize()
                    ready = true
                } catch {
                    // Still allow the UI to open with demo content if the core
                    // fails to initialize (e.g. no station module bundled).
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
