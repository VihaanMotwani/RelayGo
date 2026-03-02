import SwiftUI

@main
struct RelayGoApp: App {
    @StateObject private var relay = RelayService()
    @ObservedObject private var bridge = FlutterBridge.shared

    var body: some Scene {
        WindowGroup {
            if bridge.isInitialized {
                ContentView()
                    .environmentObject(relay)
                    .environmentObject(bridge)
            } else {
                LoadingView()
                    .environmentObject(relay)
                    .environmentObject(bridge)
            }
        }
    }
}

// MARK: - Loading View

struct LoadingView: View {
    @EnvironmentObject var relay: RelayService
    @EnvironmentObject var bridge: FlutterBridge

    @State private var showError = false

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [Color.orange.opacity(0.8), Color.red.opacity(0.9)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                // Logo
                VStack(spacing: 16) {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.system(size: 80))
                        .foregroundColor(.white)
                        .symbolEffect(.pulse, isActive: bridge.isInitializing)

                    Text("RelayGo")
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .foregroundColor(.white)

                    Text("Emergency Mesh Network")
                        .font(.headline)
                        .foregroundColor(.white.opacity(0.8))
                }

                Spacer()

                // Progress
                VStack(spacing: 16) {
                    if bridge.isInitializing {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.2)
                    }

                    Text(bridge.initProgress)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    if let error = relay.initError {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.yellow)
                            .padding(.horizontal)
                    }
                }
                .frame(height: 100)

                Spacer()

                // Start button (only if not auto-starting)
                if !bridge.isInitializing && !bridge.isInitialized {
                    Button {
                        Task {
                            await relay.initializeEngine()
                        }
                    } label: {
                        Text("Initialize")
                            .font(.headline)
                            .foregroundColor(.orange)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.white)
                            .cornerRadius(16)
                    }
                    .padding(.horizontal, 40)
                }

                Spacer()
                    .frame(height: 60)
            }
        }
        .task {
            // Auto-initialize on appear
            await relay.initializeEngine()
        }
    }
}
