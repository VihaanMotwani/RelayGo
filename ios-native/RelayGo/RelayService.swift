import SwiftUI
import Combine

// MARK: - Models

struct Broadcast: Identifiable, Equatable {
    let id: String
    let sender: String
    let message: String
    let timestamp: Date
    let hops: Int
    let isEmergency: Bool

    var timeAgo: String {
        let seconds = Int(Date().timeIntervalSince(timestamp))
        if seconds < 60 { return "now" }
        if seconds < 3600 { return "\(seconds / 60)m" }
        return "\(seconds / 3600)h"
    }

    init(id: String, sender: String, message: String, timestamp: Date, hops: Int, isEmergency: Bool) {
        self.id = id
        self.sender = sender
        self.message = message
        self.timestamp = timestamp
        self.hops = hops
        self.isEmergency = isEmergency
    }

    init(from packet: MeshPacketData) {
        self.id = packet.id
        self.sender = packet.source
        self.message = packet.body ?? ""
        self.timestamp = Date(timeIntervalSince1970: TimeInterval(packet.timestamp))
        self.hops = packet.hops
        self.isEmergency = packet.isEmergency
    }
}

struct ChatMessage: Identifiable, Equatable {
    let id = UUID()
    let isUser: Bool
    let text: String
    let timestamp: Date
    let isVerified: Bool

    init(isUser: Bool, text: String, timestamp: Date = Date(), isVerified: Bool = false) {
        self.isUser = isUser
        self.text = text
        self.timestamp = timestamp
        self.isVerified = isVerified
    }
}

// MARK: - Service

@MainActor
class RelayService: ObservableObject {

    private let bridge = FlutterBridge.shared

    // Initialization state
    @Published var isEngineReady = false
    @Published var initProgress = "Starting..."
    @Published var initError: String?

    // Connection state
    @Published var isConnected = false
    @Published var isConnecting = false
    @Published var peerCount = 0

    // SOS state
    @Published var sosActive = false
    @Published var sosSentAt: Date?

    // Broadcasts from mesh
    @Published var broadcasts: [Broadcast] = []
    @Published var unreadCount = 0

    // AI Chat
    @Published var chatMessages: [ChatMessage] = []
    @Published var isThinking = false

    // Settings
    @Published var relayEnabled: Bool {
        didSet {
            UserDefaults.standard.set(relayEnabled, forKey: "relayEnabled")
            Task {
                do {
                    try await bridge.setRelayEnabled(relayEnabled)
                    if relayEnabled && !isConnected {
                        await connect()
                    } else if !relayEnabled {
                        await disconnect()
                    }
                } catch {
                    print("Failed to set relay: \(error)")
                }
            }
        }
    }

    // Device identity
    let deviceName: String

    private var cancellables = Set<AnyCancellable>()

    init() {
        self.deviceName = UIDevice.current.name
        self.relayEnabled = UserDefaults.standard.bool(forKey: "relayEnabled")

        // Observe bridge state changes
        bridge.$initProgress
            .receive(on: DispatchQueue.main)
            .assign(to: &$initProgress)

        bridge.$peerCount
            .receive(on: DispatchQueue.main)
            .assign(to: &$peerCount)

        bridge.$isMeshConnected
            .receive(on: DispatchQueue.main)
            .assign(to: &$isConnected)

        bridge.$isInitialized
            .receive(on: DispatchQueue.main)
            .assign(to: &$isEngineReady)

        // Setup packet callback
        bridge.onMeshPacket = { [weak self] packet in
            Task { @MainActor in
                self?.handleIncomingPacket(packet)
            }
        }
    }

    // MARK: - Initialization

    func initializeEngine() async {
        guard !isEngineReady else { return }

        do {
            try await bridge.initialize()
            isEngineReady = true
            initError = nil

            // Load existing data
            await loadBroadcasts()

            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
        } catch {
            initError = error.localizedDescription
            print("Engine init failed: \(error)")
        }
    }

    private func handleIncomingPacket(_ packet: MeshPacketData) {
        let broadcast = Broadcast(from: packet)

        // Avoid duplicates
        if !broadcasts.contains(where: { $0.id == broadcast.id }) {
            broadcasts.insert(broadcast, at: 0)
            unreadCount += 1

            // Haptic for emergency
            if broadcast.isEmergency {
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.warning)
            }
        }
    }

    private func loadBroadcasts() async {
        do {
            let rawBroadcasts = try await bridge.getBroadcasts()
            let rawReports = try await bridge.getReports()

            var newBroadcasts: [Broadcast] = []

            for dict in rawBroadcasts {
                let packet = MeshPacketData(from: dict)
                newBroadcasts.append(Broadcast(from: packet))
            }

            for dict in rawReports {
                var reportDict = dict
                reportDict["kind"] = "report"
                let packet = MeshPacketData(from: reportDict)
                newBroadcasts.append(Broadcast(from: packet))
            }

            // Sort by timestamp descending
            newBroadcasts.sort { $0.timestamp > $1.timestamp }
            broadcasts = newBroadcasts
            unreadCount = newBroadcasts.count
        } catch {
            print("Failed to load broadcasts: \(error)")
        }
    }

    // MARK: - SOS Actions

    func triggerSOS() async {
        guard !sosActive else { return }

        // Connect if not connected
        if !isConnected {
            await connect()
        }

        do {
            try await bridge.sendSOS(description: "SOS - Emergency assistance needed from \(deviceName)")

            sosActive = true
            sosSentAt = Date()

            // Add to local list
            let sos = Broadcast(
                id: UUID().uuidString,
                sender: deviceName,
                message: "SOS - Emergency assistance needed",
                timestamp: Date(),
                hops: 0,
                isEmergency: true
            )
            broadcasts.insert(sos, at: 0)

            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.warning)
        } catch {
            print("Failed to send SOS: \(error)")
        }
    }

    func cancelSOS() {
        sosActive = false
        sosSentAt = nil

        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }

    // MARK: - Connection

    func connect() async {
        guard !isConnected && !isConnecting else { return }

        isConnecting = true

        do {
            try await bridge.startMesh()
            isConnected = true

            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
        } catch {
            print("Failed to connect: \(error)")
        }

        isConnecting = false
    }

    func disconnect() async {
        do {
            try await bridge.stopMesh()
            isConnected = false
            peerCount = 0
            sosActive = false
        } catch {
            print("Failed to disconnect: \(error)")
        }
    }

    // MARK: - Broadcasts

    func sendBroadcast(_ message: String) async {
        do {
            try await bridge.sendBroadcast(message)

            let broadcast = Broadcast(
                id: UUID().uuidString,
                sender: deviceName,
                message: message,
                timestamp: Date(),
                hops: 0,
                isEmergency: false
            )
            broadcasts.insert(broadcast, at: 0)
        } catch {
            print("Failed to send broadcast: \(error)")
        }
    }

    func markAsRead() {
        unreadCount = 0
    }

    // MARK: - AI Chat

    func sendToAI(_ text: String) async {
        let userMessage = ChatMessage(isUser: true, text: text, isVerified: false)
        chatMessages.append(userMessage)

        isThinking = true

        do {
            let response = try await bridge.chat(text, extractReport: false)
            let aiMessage = ChatMessage(
                isUser: false,
                text: response.text,
                isVerified: response.isVerified
            )
            chatMessages.append(aiMessage)
        } catch {
            let errorMessage = ChatMessage(
                isUser: false,
                text: "Sorry, I couldn't process that. Error: \(error.localizedDescription)",
                isVerified: false
            )
            chatMessages.append(errorMessage)
        }

        isThinking = false
    }

    func transcribeAndSend(audioPath: String) async {
        isThinking = true

        do {
            let transcription = try await bridge.transcribe(audioPath: audioPath)

            if transcription.isEmpty || transcription.starts(with: "[") {
                // Transcription failed or unavailable
                let errorMessage = ChatMessage(
                    isUser: false,
                    text: "Voice transcription unavailable. Please type your message.",
                    isVerified: false
                )
                chatMessages.append(errorMessage)
                isThinking = false
                return
            }

            // Show transcription as user message
            let userMessage = ChatMessage(isUser: true, text: transcription, isVerified: false)
            chatMessages.append(userMessage)

            // Get AI response
            let response = try await bridge.chat(transcription, extractReport: false)
            let aiMessage = ChatMessage(
                isUser: false,
                text: response.text,
                isVerified: response.isVerified
            )
            chatMessages.append(aiMessage)
        } catch {
            let errorMessage = ChatMessage(
                isUser: false,
                text: "Failed to process voice: \(error.localizedDescription)",
                isVerified: false
            )
            chatMessages.append(errorMessage)
        }

        isThinking = false

        // Clean up audio file
        try? FileManager.default.removeItem(atPath: audioPath)
    }

    // MARK: - Awareness Summary

    func generateSummary() async -> String {
        do {
            return try await bridge.generateAwarenessSummary()
        } catch {
            return "Unable to generate summary: \(error.localizedDescription)"
        }
    }
}
