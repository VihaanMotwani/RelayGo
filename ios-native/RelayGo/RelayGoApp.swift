import SwiftUI

@main
struct RelayGoApp: App {
    @StateObject private var relay = RelayService()
    @ObservedObject private var bridge = FlutterBridge.shared
    @State private var showSplash = true

    var body: some Scene {
        WindowGroup {
            Group {
                if showSplash {
                    SplashView()
                } else {
                    ContentView()
                        .environmentObject(relay)
                        .environmentObject(bridge)
                }
            }
            .task {
                // Start initialization in background
                Task {
                    await relay.initializeEngine()
                }
                // Show splash briefly then transition to app
                try? await Task.sleep(for: .seconds(1.5))
                showSplash = false
            }
        }
    }
}

// MARK: - Splash View (brief startup screen)

struct SplashView: View {
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [Color.orange.opacity(0.8), Color.red.opacity(0.9)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 16) {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 80))
                    .foregroundColor(.white)
                    .symbolEffect(.pulse)

                Text("RelayGo")
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                Text("Emergency Mesh Network")
                    .font(.headline)
                    .foregroundColor(.white.opacity(0.8))
            }
        }
    }
}
