import SwiftUI

struct NearbyView: View {
    @EnvironmentObject var relay: RelayService
    @State private var messageText = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Connection status banner
                if relay.isConnecting {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Connecting to mesh network...")
                            .font(.subheadline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.orange.opacity(0.2))
                }

                if !relay.isConnected && !relay.isConnecting {
                    // Not connected state
                    ContentUnavailableView {
                        Label("Not Connected", systemImage: "antenna.radiowaves.left.and.right.slash")
                    } description: {
                        Text("Connect to the mesh network to see broadcasts from nearby devices.")
                    } actions: {
                        Button {
                            Task { await relay.connect() }
                        } label: {
                            Text("Connect")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else if relay.broadcasts.isEmpty && relay.isConnected {
                    // Connected but no messages
                    ContentUnavailableView {
                        Label("No Messages Yet", systemImage: "bubble.left.and.bubble.right")
                    } description: {
                        Text("Broadcasts from nearby devices will appear here. Send one to get started!")
                    }
                } else {
                    // Broadcast list
                    List {
                        ForEach(relay.broadcasts) { broadcast in
                            BroadcastRow(broadcast: broadcast)
                                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        }
                    }
                    .listStyle(.plain)
                    .refreshable {
                        // Refresh broadcasts from Flutter
                        await relay.initializeEngine()
                    }
                }

                // Input bar (only when connected)
                if relay.isConnected {
                    Divider()

                    HStack(spacing: 12) {
                        TextField("Broadcast to nearby...", text: $messageText)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit(sendBroadcast)

                        Button(action: sendBroadcast) {
                            Image(systemName: "paperplane.fill")
                                .foregroundStyle(messageText.isEmpty ? .gray : .blue)
                        }
                        .disabled(messageText.isEmpty)
                    }
                    .padding()
                    .background(.bar)
                }
            }
            .navigationTitle("Nearby")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if relay.isConnected {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(.green)
                                .frame(width: 8, height: 8)
                            Text("Connected")
                                .font(.caption)
                        }
                        .foregroundStyle(.secondary)
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    if relay.isConnected {
                        HStack(spacing: 4) {
                            Image(systemName: "person.2.fill")
                                .font(.caption)
                            Text("\(relay.peerCount)")
                                .font(.caption.bold())
                        }
                        .foregroundStyle(.secondary)
                    }
                }
            }
            .onAppear {
                relay.markAsRead()
            }
        }
    }

    private func sendBroadcast() {
        let text = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        messageText = ""

        Task {
            await relay.sendBroadcast(text)
        }
    }
}

// MARK: - Broadcast Row

struct BroadcastRow: View {
    let broadcast: Broadcast

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header
            HStack {
                Text(broadcast.sender)
                    .font(.subheadline.bold())
                    .foregroundStyle(broadcast.isEmergency ? .red : .primary)

                if broadcast.isEmergency {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                Spacer()

                HStack(spacing: 4) {
                    if broadcast.hops > 0 {
                        Image(systemName: "arrow.triangle.branch")
                            .font(.caption2)
                        Text("\(broadcast.hops) hops")
                            .font(.caption2)
                    }
                    Text(broadcast.timeAgo)
                        .font(.caption)
                }
                .foregroundStyle(.tertiary)
            }

            // Message
            Text(broadcast.message)
                .font(.body)
                .foregroundStyle(broadcast.isEmergency ? .red : .primary)
        }
        .padding(.vertical, 4)
        .background(broadcast.isEmergency ? Color.red.opacity(0.05) : .clear)
    }
}

#Preview {
    NearbyView()
        .environmentObject(RelayService())
}
