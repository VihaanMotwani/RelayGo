import Foundation
import UIKit
import Flutter
import Combine

/// Bridge between SwiftUI and Flutter engine
/// Communicates via MethodChannel "com.relaygo/bridge"
class FlutterBridge: ObservableObject {
    static let shared = FlutterBridge()

    private var flutterEngine: FlutterEngine?
    private var methodChannel: FlutterMethodChannel?

    // State published to SwiftUI
    @MainActor @Published var isInitialized = false
    @MainActor @Published var isAiReady = false
    @MainActor @Published var isMeshConnected = false
    @MainActor @Published var peerCount = 0
    @MainActor @Published var initProgress = "Starting..."
    @MainActor @Published var isInitializing = false

    // Callbacks for events from Flutter
    var onMeshPacket: ((MeshPacketData) -> Void)?
    var onPeerCountChanged: ((Int) -> Void)?
    var onConnectionStatusChanged: ((String) -> Void)?

    private init() {}

    // MARK: - Engine Setup

    @MainActor
    func startEngine() {
        guard flutterEngine == nil else { return }

        print("[RelayGo] Starting Flutter engine...")

        // Create and run the Flutter engine
        let engine = FlutterEngine(name: "RelayGoEngine")
        engine.run()
        print("[RelayGo] Flutter engine running")

        // Register plugins
        GeneratedPluginRegistrant.register(with: engine)
        print("[RelayGo] Plugins registered")

        flutterEngine = engine

        // Setup method channel
        let channel = FlutterMethodChannel(
            name: "com.relaygo/bridge",
            binaryMessenger: engine.binaryMessenger
        )

        // Handle events pushed from Flutter
        channel.setMethodCallHandler { [weak self] call, result in
            self?.handleFlutterCall(call, result: result)
        }

        methodChannel = channel
        print("[RelayGo] Method channel ready")
    }

    // MARK: - Handle events FROM Flutter

    private func handleFlutterCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        Task { @MainActor in
            switch call.method {
            case "onInitProgress":
                if let args = call.arguments as? [String: Any],
                   let progress = args["progress"] as? String {
                    print("[RelayGo] Progress: \(progress)")
                    self.initProgress = progress
                }
                result(nil)

            case "onMeshPacket":
                if let args = call.arguments as? [String: Any] {
                    let packet = MeshPacketData(from: args)
                    self.onMeshPacket?(packet)
                }
                result(nil)

            case "onPeerCountChanged":
                if let args = call.arguments as? [String: Any],
                   let count = args["count"] as? Int {
                    self.peerCount = count
                    self.onPeerCountChanged?(count)
                }
                result(nil)

            case "onConnectionStatus":
                if let args = call.arguments as? [String: Any],
                   let status = args["status"] as? String {
                    self.isMeshConnected = (status == "connected")
                    self.onConnectionStatusChanged?(status)
                }
                result(nil)

            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }

    // MARK: - Call Flutter methods

    private func invoke(_ method: String, arguments: [String: Any]? = nil) async throws -> [String: Any]? {
        guard let channel = methodChannel else {
            print("[RelayGo] ERROR: Method channel not initialized")
            throw BridgeError.notInitialized
        }

        print("[RelayGo] Invoking Flutter method: \(method)")
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.main.async {
                channel.invokeMethod(method, arguments: arguments) { result in
                    if let error = result as? FlutterError {
                        print("[RelayGo] ERROR from Flutter: \(error.message ?? "unknown")")
                        continuation.resume(throwing: BridgeError.flutterError(error.message ?? "Unknown error"))
                    } else if let dict = result as? [String: Any] {
                        print("[RelayGo] Method \(method) returned successfully")
                        continuation.resume(returning: dict)
                    } else {
                        print("[RelayGo] Method \(method) returned nil")
                        continuation.resume(returning: nil)
                    }
                }
            }
        }
    }

    // MARK: - Public API

    @MainActor
    func initialize() async throws {
        guard !isInitializing else { return }
        isInitializing = true
        initProgress = "Starting Flutter engine..."
        print("[RelayGo] ========== INITIALIZATION STARTED ==========")

        startEngine()

        // Small delay to let engine start
        try await Task.sleep(for: .milliseconds(500))

        initProgress = "Initializing services..."
        print("[RelayGo] Calling Flutter initialize()...")
        let _ = try await invoke("initialize")
        print("[RelayGo] Flutter initialize() completed")

        // Get initial state
        print("[RelayGo] Getting state from Flutter...")
        if let state = try await invoke("getState") {
            isInitialized = state["isInitialized"] as? Bool ?? false
            isAiReady = state["isAiReady"] as? Bool ?? false
            isMeshConnected = state["isMeshConnected"] as? Bool ?? false
            peerCount = state["peerCount"] as? Int ?? 0
            print("[RelayGo] State: initialized=\(isInitialized), aiReady=\(isAiReady), mesh=\(isMeshConnected), peers=\(peerCount)")
        }

        isInitializing = false
        print("[RelayGo] ========== INITIALIZATION COMPLETE ==========")
    }

    @MainActor
    func refreshState() async throws {
        if let state = try await invoke("getState") {
            isInitialized = state["isInitialized"] as? Bool ?? false
            isAiReady = state["isAiReady"] as? Bool ?? false
            isMeshConnected = state["isMeshConnected"] as? Bool ?? false
            peerCount = state["peerCount"] as? Int ?? 0
        }
    }

    // MARK: - AI Methods

    func chat(_ text: String, extractReport: Bool = false) async throws -> ChatResponse {
        let result = try await invoke("chat", arguments: [
            "text": text,
            "extractReport": extractReport
        ])

        guard let result = result else {
            throw BridgeError.invalidResponse
        }

        return ChatResponse(
            text: result["text"] as? String ?? "",
            confidence: result["confidence"] as? String ?? "unverified",
            extraction: result["extraction"] as? [String: Any]
        )
    }

    func transcribe(audioPath: String) async throws -> String {
        let result = try await invoke("transcribe", arguments: [
            "audioPath": audioPath
        ])
        return result?["text"] as? String ?? ""
    }

    func generateAwarenessSummary() async throws -> String {
        let result = try await invoke("generateAwarenessSummary")
        return result?["summary"] as? String ?? "Unable to generate summary"
    }

    // MARK: - Mesh Methods

    @MainActor
    func startMesh() async throws {
        let _ = try await invoke("startMesh")
        isMeshConnected = true
    }

    @MainActor
    func stopMesh() async throws {
        let _ = try await invoke("stopMesh")
        isMeshConnected = false
    }

    func sendSOS(description: String? = nil) async throws {
        var args: [String: Any] = [:]
        if let desc = description {
            args["description"] = desc
        }
        let _ = try await invoke("sendSOS", arguments: args.isEmpty ? nil : args)
    }

    func sendBroadcast(_ message: String) async throws {
        let _ = try await invoke("sendBroadcast", arguments: ["message": message])
    }

    func sendDirectMessage(to peerId: String, message: String) async throws {
        let _ = try await invoke("sendDirectMessage", arguments: [
            "peerId": peerId,
            "message": message
        ])
    }

    func getReports() async throws -> [[String: Any]] {
        let result = try await invoke("getReports")
        return result?["reports"] as? [[String: Any]] ?? []
    }

    func getBroadcasts() async throws -> [[String: Any]] {
        let result = try await invoke("getBroadcasts")
        return result?["broadcasts"] as? [[String: Any]] ?? []
    }

    func getPeers() async throws -> [[String: Any]] {
        let result = try await invoke("getPeers")
        return result?["peers"] as? [[String: Any]] ?? []
    }

    // MARK: - Settings

    func setRelayEnabled(_ enabled: Bool) async throws {
        let _ = try await invoke("setRelayEnabled", arguments: ["enabled": enabled])
    }

    func setDisplayName(_ name: String) async throws {
        let _ = try await invoke("setDisplayName", arguments: ["name": name])
    }
}

// MARK: - Data Types

enum BridgeError: Error, LocalizedError {
    case notInitialized
    case flutterError(String)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .notInitialized:
            return "Flutter engine not initialized"
        case .flutterError(let message):
            return "Flutter error: \(message)"
        case .invalidResponse:
            return "Invalid response from Flutter"
        }
    }
}

struct ChatResponse {
    let text: String
    let confidence: String
    let extraction: [String: Any]?

    var isVerified: Bool {
        confidence == "verified"
    }
}

struct MeshPacketData {
    let kind: String // "report" or "message"
    let id: String
    let timestamp: Int
    let source: String
    let body: String?
    let isEmergency: Bool
    let hops: Int

    init(from dict: [String: Any]) {
        kind = dict["kind"] as? String ?? "message"
        id = dict["id"] as? String ?? UUID().uuidString
        timestamp = dict["ts"] as? Int ?? Int(Date().timeIntervalSince1970)
        source = dict["src"] as? String ?? dict["name"] as? String ?? "Unknown"
        body = dict["body"] as? String ?? dict["desc"] as? String
        isEmergency = (dict["urg"] as? Int ?? 0) >= 4 || kind == "report"
        hops = dict["hops"] as? Int ?? 0
    }
}
