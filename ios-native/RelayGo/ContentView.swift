import SwiftUI

struct ContentView: View {
    @EnvironmentObject var relay: RelayService
    @State private var showingSettings = false

    var body: some View {
        TabView {
            SOSView()
                .tabItem {
                    Label("SOS", systemImage: "sos.circle.fill")
                }

            ChatView()
                .tabItem {
                    Label("Assistant", systemImage: "bubble.left.and.bubble.right")
                }

            NearbyView()
                .tabItem {
                    Label("Nearby", systemImage: relay.unreadCount > 0 ? "antenna.radiowaves.left.and.right.circle.fill" : "antenna.radiowaves.left.and.right")
                }
                .badge(relay.unreadCount)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
        }
        .tint(.red)
    }
}

#Preview {
    ContentView()
        .environmentObject(RelayService())
}
