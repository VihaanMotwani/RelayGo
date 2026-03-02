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
                            .fill(relay.sosActive ? .red : .red.opacity(0.9))
                            .frame(width: 200, height: 200)
                            .shadow(color: .red.opacity(0.4), radius: relay.sosActive ? 30 : 15)

                        VStack(spacing: 4) {
                            if relay.sosActive {
                                Text("SOS")
                                    .font(.system(size: 42, weight: .bold, design: .rounded))
                                Text("ACTIVE")
                                    .font(.caption.bold())
                            } else if relay.isConnected {
                                Text("SOS")
                                    .font(.system(size: 42, weight: .bold, design: .rounded))
                                Text("Send Alert")
                                    .font(.caption.bold())
                            } else {
                                Text("Connect")
                                    .font(.system(size: 32, weight: .bold, design: .rounded))
                                Text("to Relay")
                                    .font(.system(size: 32, weight: .bold, design: .rounded))
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
