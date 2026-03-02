import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var relay: RelayService

    var body: some View {
        NavigationStack {
            List {
                // Relay Section
                Section {
                    Toggle(isOn: $relay.relayEnabled) {
                        Label("Background Relay", systemImage: "antenna.radiowaves.left.and.right")
                    }
                } header: {
                    Text("Mesh Network")
                } footer: {
                    Text("When enabled, your device helps relay emergency broadcasts from others and uploads data to responders when you have internet. This runs in the background.")
                }

                // Status Section
                Section("Status") {
                    HStack {
                        Text("Connection")
                        Spacer()
                        HStack(spacing: 6) {
                            Circle()
                                .fill(relay.isConnected ? .green : .gray)
                                .frame(width: 8, height: 8)
                            Text(relay.isConnected ? "Connected" : "Disconnected")
                                .foregroundStyle(.secondary)
                        }
                    }

                    if relay.isConnected {
                        HStack {
                            Text("Nearby Devices")
                            Spacer()
                            Text("\(relay.peerCount)")
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // About Section
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(.secondary)
                    }

                    Link(destination: URL(string: "https://relaygo.app/privacy")!) {
                        HStack {
                            Text("Privacy Policy")
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .foregroundStyle(.primary)
                }

                // Info Section
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("How Relay Works", systemImage: "info.circle")
                            .font(.subheadline.bold())

                        Text("RelayGo creates a mesh network using Bluetooth. When you enable relay mode:")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        VStack(alignment: .leading, spacing: 4) {
                            BulletPoint("Your device receives emergency broadcasts from nearby phones")
                            BulletPoint("Messages hop through devices to reach further")
                            BulletPoint("When you have internet, data is uploaded to emergency responders")
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct BulletPoint: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Text("•")
            Text(text)
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(RelayService())
}
