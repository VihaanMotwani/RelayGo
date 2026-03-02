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
    let id: UUID
    let isUser: Bool
    var text: String  // Mutable for streaming
    let timestamp: Date
    var isVerified: Bool  // Mutable - set when streaming completes
    var isStreaming: Bool  // Track if currently streaming

    init(id: UUID = UUID(), isUser: Bool, text: String = "", timestamp: Date = Date(), isVerified: Bool = false, isStreaming: Bool = false) {
        self.id = id
        self.isUser = isUser
        self.text = text
        self.timestamp = timestamp
        self.isVerified = isVerified
        self.isStreaming = isStreaming
    }

    static func == (lhs: ChatMessage, rhs: ChatMessage) -> Bool {
        lhs.id == rhs.id && lhs.text == rhs.text && lhs.isStreaming == rhs.isStreaming && lhs.isVerified == rhs.isVerified
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
    @Published var isStreaming = false
    private var currentStreamingMessageId: UUID?
    private var lastUserMessageText: String?  // For extraction after streaming
    @Published var isSttReady = false

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

        bridge.$isSttReady
            .receive(on: DispatchQueue.main)
            .assign(to: &$isSttReady)

        // Setup packet callback
        bridge.onMeshPacket = { [weak self] packet in
            Task { @MainActor in
                self?.handleIncomingPacket(packet)
            }
        }

        // Setup streaming callbacks
        bridge.onStreamToken = { [weak self] token in
            Task { @MainActor in
                self?.handleStreamToken(token)
            }
        }

        bridge.onStreamDone = { [weak self] confidence in
            Task { @MainActor in
                self?.handleStreamDone(confidence: confidence)
            }
        }

        bridge.onStreamError = { [weak self] error in
            Task { @MainActor in
                self?.handleStreamError(error)
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

            // Also extract and broadcast as emergency report if urgent
            await extractAndBroadcastIfNeeded(message)
        } catch {
            print("Failed to send broadcast: \(error)")
        }
    }

    func markAsRead() {
        unreadCount = 0
    }

    // MARK: - AI Chat

    func sendToAI(_ text: String) async {
        // Store for extraction after streaming completes
        lastUserMessageText = text

        // Add user message
        let userMessage = ChatMessage(isUser: true, text: text, isVerified: false)
        chatMessages.append(userMessage)

        // Create placeholder AI message for streaming
        let aiMessageId = UUID()
        let aiMessage = ChatMessage(
            id: aiMessageId,
            isUser: false,
            text: "",
            isVerified: false,
            isStreaming: true
        )
        chatMessages.append(aiMessage)
        currentStreamingMessageId = aiMessageId

        isThinking = true
        isStreaming = true

        do {
            try await bridge.startStreamingChat(text)
            // Tokens will arrive via handleStreamToken callback
        } catch {
            // Fallback to non-streaming if streaming fails
            handleStreamError(error.localizedDescription)
        }
    }

    /// Handle incoming token from streaming
    private func handleStreamToken(_ token: String) {
        guard let messageId = currentStreamingMessageId,
              let index = chatMessages.firstIndex(where: { $0.id == messageId }) else {
            return
        }

        // Hide thinking indicator as soon as first token arrives
        if isThinking {
            isThinking = false
        }

        // Append token to the streaming message (sanitization happens at stream end)
        chatMessages[index].text += token
    }

    /// Handle stream completion
    private func handleStreamDone(confidence: String) {
        guard let messageId = currentStreamingMessageId,
              let index = chatMessages.firstIndex(where: { $0.id == messageId }) else {
            return
        }

        // Final cleanup pass (in case any fragments slipped through during streaming)
        chatMessages[index].text = sanitizeAssistantText(chatMessages[index].text)

        // Mark message as complete
        chatMessages[index].isStreaming = false
        chatMessages[index].isVerified = (confidence == "verified")

        // Reset state
        currentStreamingMessageId = nil
        isThinking = false
        isStreaming = false

        // Haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)

        // If mesh is connected, extract emergency info and broadcast
        if isConnected, let userText = lastUserMessageText {
            Task {
                await extractAndBroadcastIfNeeded(userText)
            }
        }
        lastUserMessageText = nil
    }

    /// Extract emergency info from text and broadcast to mesh if urgent
    private func extractAndBroadcastIfNeeded(_ text: String) async {
        guard isConnected else { return }

        do {
            let extraction = try await bridge.extractAndBroadcast(text)
            if let extraction = extraction {
                print("[RelayService] Extracted and broadcast: \(extraction["type"] ?? "unknown") urg=\(extraction["urgency"] ?? 0)")
            }
        } catch {
            print("[RelayService] Extraction failed: \(error)")
        }
    }

    /// Handle stream error
    private func handleStreamError(_ error: String) {
        if let messageId = currentStreamingMessageId,
           let index = chatMessages.firstIndex(where: { $0.id == messageId }) {
            // Update the streaming message with error
            chatMessages[index].text = "Sorry, I couldn't process that. Error: \(error)"
            chatMessages[index].isStreaming = false
        } else {
            // Create error message if no streaming message exists
            let errorMessage = ChatMessage(
                isUser: false,
                text: "Sorry, I couldn't process that. Error: \(error)",
                isVerified: false
            )
            chatMessages.append(errorMessage)
        }

        // Reset state
        currentStreamingMessageId = nil
        isThinking = false
        isStreaming = false
    }

    /// Cancel ongoing streaming
    func cancelStreaming() async {
        guard isStreaming else { return }

        do {
            try await bridge.cancelStreamingChat()
        } catch {
            print("Failed to cancel streaming: \(error)")
        }

        if let messageId = currentStreamingMessageId,
           let index = chatMessages.firstIndex(where: { $0.id == messageId }) {
            chatMessages[index].isStreaming = false
            if chatMessages[index].text.isEmpty {
                chatMessages[index].text = "[Cancelled]"
            }
        }

        currentStreamingMessageId = nil
        isThinking = false
        isStreaming = false
    }

    func transcribeAndSend(audioPath: String) async {
        // Add placeholder user message immediately
        let placeholderId = UUID()
        let placeholderMessage = ChatMessage(
            id: placeholderId,
            isUser: true,
            text: "Transcribing...",
            isVerified: false
        )
        chatMessages.append(placeholderMessage)

        do {
            let transcription = try await bridge.transcribe(audioPath: audioPath)

            if transcription.isEmpty || transcription.starts(with: "[") {
                // Transcription failed - remove placeholder and show error
                chatMessages.removeAll { $0.id == placeholderId }

                let detail = transcription
                    .trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
                let errorMessage = ChatMessage(
                    isUser: false,
                    text: detail.isEmpty
                        ? "Voice transcription unavailable. Please type your message."
                        : "\(detail). Please type your message.",
                    isVerified: false
                )
                chatMessages.append(errorMessage)

                // Clean up audio file
                try? FileManager.default.removeItem(atPath: audioPath)
                return
            }

            // Update placeholder with actual transcription
            if let index = chatMessages.firstIndex(where: { $0.id == placeholderId }) {
                chatMessages[index].text = transcription
            }

            // Clean up audio file
            try? FileManager.default.removeItem(atPath: audioPath)

            // Store for extraction after streaming completes
            lastUserMessageText = transcription

            // Create placeholder AI message for streaming
            let aiMessageId = UUID()
            let aiMessage = ChatMessage(
                id: aiMessageId,
                isUser: false,
                text: "",
                isVerified: false,
                isStreaming: true
            )
            chatMessages.append(aiMessage)
            currentStreamingMessageId = aiMessageId

            isThinking = true
            isStreaming = true

            // Start streaming AI response
            do {
                try await bridge.startStreamingChat(transcription)
            } catch {
                handleStreamError(error.localizedDescription)
            }
        } catch {
            // Remove placeholder and show error
            chatMessages.removeAll { $0.id == placeholderId }

            let errorMessage = ChatMessage(
                isUser: false,
                text: "Failed to process voice: \(error.localizedDescription)",
                isVerified: false
            )
            chatMessages.append(errorMessage)

            // Clean up audio file
            try? FileManager.default.removeItem(atPath: audioPath)
        }
    }

    // MARK: - Awareness Summary

    func generateSummary() async -> String {
        do {
            return try await bridge.generateAwarenessSummary()
        } catch {
            return "Unable to generate summary: \(error.localizedDescription)"
        }
    }

    // MARK: - Output Sanitation

    /// Defensive cleanup for leaked reasoning/meta output from local LLMs.
    /// Keeps chat user-facing even when model emits internal tags/JSON.
    private func sanitizeAssistantText(_ text: String) -> String {
        var cleaned = text
            .replacingOccurrences(
                of: "(?is)<think>[\\s\\S]*?</think>",
                with: " ",
                options: .regularExpression
            )
            .replacingOccurrences(
                of: "(?is)<analysis>[\\s\\S]*?</analysis>",
                with: " ",
                options: .regularExpression
            )
            .replacingOccurrences(
                of: "(?m)^\\s*```[a-zA-Z0-9_-]*\\s*",
                with: "",
                options: .regularExpression
            )
            .replacingOccurrences(of: "```", with: "")
            .replacingOccurrences(
                of: "(?im)^\\s*(assistant|system|user)\\s*:\\s*",
                with: "",
                options: .regularExpression
            )
            .replacingOccurrences(
                of: "</?(think|analysis)>",
                with: "",
                options: .regularExpression
            )
            .replacingOccurrences(
                of: "\\n{3,}",
                with: "\n\n",
                options: .regularExpression
            )
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let lower = cleaned.lowercased()
        if cleaned.isEmpty ||
            lower == "json" ||
            lower.hasPrefix("okay, the user") ||
            lower.contains("let me start by") ||
            lower.contains("i need to respond") {
            return "I am here to help. Tell me what happened and where you are for immediate steps."
        }

        return cleaned
    }
}
