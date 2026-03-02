import SwiftUI

struct SOSView: View {
    @EnvironmentObject var relay: RelayService

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Spacer()

                // Main SOS Button
                Button {
                    Task { await relay.triggerSOS() }
                } label: {
                    ZStack {
                        // Pulsing background when active
                        if relay.sosActive {
                            Circle()
                                .fill(.red.opacity(0.2))
                                .frame(width: 260, height: 260)
                                .modifier(PulseAnimation())
                        }

                        Circle()
                            .fill(
                                relay.sosActive
                                    ? LinearGradient(
                                        colors: [Color(red: 0.9, green: 0.2, blue: 0.2), Color(red: 0.7, green: 0.1, blue: 0.1)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                    : LinearGradient(
                                        colors: [Color(red: 0.95, green: 0.35, blue: 0.35), Color(red: 0.75, green: 0.15, blue: 0.2)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                            )
                            .frame(width: 200, height: 200)
                            .overlay(
                                Circle()
                                    .strokeBorder(
                                        LinearGradient(
                                            colors: [.white.opacity(0.3), .clear],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 2
                                    )
                            )
                            .shadow(color: .red.opacity(0.5), radius: relay.sosActive ? 25 : 12, y: 4)

                        VStack(spacing: 2) {
                            if relay.sosActive {
                                Text("RELAY")
                                    .font(.system(size: 38, weight: .heavy, design: .rounded))
                                Text("ACTIVE")
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                                    .tracking(2)
                            } else if relay.isConnected {
                                Text("TAP TO")
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                                    .tracking(1)
                                Text("RELAY")
                                    .font(.system(size: 38, weight: .heavy, design: .rounded))
                            } else {
                                Text("TAP TO")
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                                    .tracking(1)
                                    .opacity(0.8)
                                Text("CONNECT")
                                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                            }
                        }
                        .foregroundStyle(.white)
                    }
                }
                .buttonStyle(.plain)
                .disabled(relay.isConnecting)

                Spacer()

                // Status section
                VStack(spacing: 16) {
                    // Connection status
                    HStack(spacing: 8) {
                        Circle()
                            .fill(statusColor)
                            .frame(width: 10, height: 10)

                        Text(statusText)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        if relay.peerCount > 0 {
                            Text("(\(relay.peerCount) nearby)")
                                .font(.subheadline)
                                .foregroundStyle(.tertiary)
                        }
                    }

                    // Cancel button when SOS active
                    if relay.sosActive {
                        Button("Cancel SOS", role: .destructive) {
                            relay.cancelSOS()
                        }
                        .buttonStyle(.bordered)
                    }

                    // Info text when disconnected
                    if !relay.isConnected && !relay.isConnecting && !relay.sosActive {
                        Text("Press SOS to connect and broadcast")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.bottom, 40)
            }
            .navigationTitle("RelayGo")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var statusColor: Color {
        if relay.isConnecting { return .orange }
        if relay.isConnected { return .green }
        return .gray
    }

    private var statusText: String {
        if relay.isConnecting { return "Connecting..." }
        if relay.sosActive { return "SOS Broadcast Active" }
        if relay.isConnected { return "Connected to Mesh" }
        return "Not Connected"
    }
}

// MARK: - Pulse Animation

struct PulseAnimation: ViewModifier {
    @State private var isPulsing = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPulsing ? 1.1 : 1.0)
            .opacity(isPulsing ? 0.5 : 0.8)
            .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: isPulsing)
            .onAppear { isPulsing = true }
    }
}

#Preview {
    SOSView()
        .environmentObject(RelayService())
}
