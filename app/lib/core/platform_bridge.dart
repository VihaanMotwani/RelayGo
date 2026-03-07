import 'dart:async';
import 'package:flutter/services.dart';

import '../models/emergency_report.dart';
import '../models/mesh_message.dart';
import '../services/ai/ai_service.dart';
import '../services/mesh/mesh_service.dart';
import '../services/location_service.dart';

/// PlatformBridge exposes all RelayGo functionality to both:
/// 1. Flutter UI (direct Dart calls)
/// 2. Native UI (via MethodChannel for SwiftUI/Compose)
///
/// This allows swapping the UI layer without changing the core logic.
class PlatformBridge {
  static PlatformBridge? _instance;
  static PlatformBridge get instance => _instance ??= PlatformBridge._();

  PlatformBridge._() {
    _setupMethodChannel();
    _setupStreamChannel();
  }

  // Services
  final AiService _aiService = AiService();
  final MeshService _meshService = MeshService();

  // Platform channel for native UI communication
  static const _channel = MethodChannel('com.relaygo/bridge');

  // Current streaming state
  StreamSubscription<String>? _currentStreamSubscription;

  // Stream controllers for pushing events to listeners (Flutter UI or native)
  final _initProgressController = StreamController<String>.broadcast();
  final _meshPacketController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _peerCountController = StreamController<int>.broadcast();
  final _connectionStatusController = StreamController<String>.broadcast();

  // Public streams for Flutter UI
  Stream<String> get initProgress => _initProgressController.stream;
  Stream<Map<String, dynamic>> get onMeshPacket => _meshPacketController.stream;
  Stream<int> get onPeerCountChanged => _peerCountController.stream;
  Stream<String> get onConnectionStatusChanged =>
      _connectionStatusController.stream;

  // State
  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;
  bool get isAiReady => _aiService.isReady;
  bool get isSttReady => _aiService.isSttReady;
  bool get isMeshConnected => _meshService.isConnected;
  int get peerCount => _meshService.peerCount;

  // ============================================================
  // INITIALIZATION
  // ============================================================

  /// Initialize all services (AI models, mesh, etc.)
  Future<void> initialize() async {
    if (_isInitialized) return;

    // Forward AI init progress
    _aiService.initProgress.listen((progress) {
      _initProgressController.add(progress);
      _pushToNative('onInitProgress', {'progress': progress});
    });

    // Initialize AI (gracefully handle failure)
    _initProgressController.add('Initializing AI...');
    try {
      await _aiService.initialize();
      if (_aiService.isReady) {
        _initProgressController.add('AI ready');
      } else {
        _initProgressController.add('AI unavailable (other features work)');
      }
    } catch (e) {
      print('[PlatformBridge] AI initialization failed: $e');
      _initProgressController.add('AI unavailable: $e');
      // Don't rethrow - continue without AI
    }

    // Initialize mesh service listeners
    _meshService.onPacketReceived.listen((packet) {
      _meshPacketController.add(packet);
      _pushToNative('onMeshPacket', packet);
    });

    _meshService.onPeersChanged.listen((peers) {
      _peerCountController.add(peers.length);
      _pushToNative('onPeerCountChanged', {'count': peers.length});
    });

    _meshService.onConnectionStatusChanged.listen((status) {
      _connectionStatusController.add(status);
      _pushToNative('onConnectionStatus', {'status': status});
    });

    _isInitialized = true;
    _initProgressController.add('Ready');
  }

  // ============================================================
  // AI METHODS
  // ============================================================

  /// Transcribe audio file to text
  Future<String> transcribe(String audioPath) async {
    return await _aiService.transcribe(audioPath);
  }

  /// Send message to AI and get response
  /// If extractAndBroadcast is true and mesh is connected, extracts emergency data and broadcasts it
  Future<Map<String, dynamic>> chat(
    String text, {
    bool extractReport = false,
    bool extractAndBroadcast = false,
  }) async {
    // Get user location for nearby resources context
    final location = await LocationService.getCurrentLocation();

    // If we should extract and broadcast, force extraction
    final shouldExtract =
        extractReport || (extractAndBroadcast && _meshService.isConnected);

    final response = await _aiService.chat(
      text,
      extractReport: shouldExtract,
      userLat: location?.latitude,
      userLon: location?.longitude,
    );

    // If extraction succeeded and mesh is connected, broadcast the report
    if (extractAndBroadcast &&
        _meshService.isConnected &&
        response.extraction != null) {
      await _broadcastExtraction(response.extraction!, location);
    }

    return {
      'text': response.text,
      'confidence': response.confidence.name,
      'extraction': response.extraction != null
          ? {
              'type': response.extraction!.type,
              'urgency': response.extraction!.urgency,
              'hazards': response.extraction!.hazards,
              'description': response.extraction!.description,
            }
          : null,
    };
  }

  /// Broadcast an extracted emergency report to the mesh network
  Future<void> _broadcastExtraction(
    AiExtraction extraction,
    dynamic location,
  ) async {
    // Only broadcast if urgency is significant (3+)
    if (extraction.urgency < 3) {
      print(
        '[PlatformBridge] Skipping broadcast - urgency ${extraction.urgency} below threshold',
      );
      return;
    }

    final report = EmergencyReport(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      ts: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      lat: location?.latitude ?? 0,
      lng: location?.longitude ?? 0,
      acc: location?.accuracy ?? 0,
      type: extraction.type,
      urg: extraction.urgency,
      haz: extraction.hazards,
      desc: extraction.description,
      src: _meshService.deviceId,
      hops: 0,
      ttl: 10,
    );

    await _meshService.broadcastReport(report);
    print(
      '[PlatformBridge] Broadcast emergency report: ${extraction.type} urg=${extraction.urgency}',
    );
  }

  /// Extract emergency data from text and broadcast if significant
  /// Used for Nearby chat messages to auto-detect emergencies
  Future<Map<String, dynamic>?> extractAndBroadcastFromText(String text) async {
    if (!_meshService.isConnected || !_aiService.isReady) {
      return null;
    }

    final location = await LocationService.getCurrentLocation();

    final response = await _aiService.chat(
      text,
      extractReport: true,
      userLat: location?.latitude,
      userLon: location?.longitude,
    );

    if (response.extraction != null) {
      await _broadcastExtraction(response.extraction!, location);
      return {
        'type': response.extraction!.type,
        'urgency': response.extraction!.urgency,
        'hazards': response.extraction!.hazards,
        'description': response.extraction!.description,
      };
    }

    return null;
  }

  /// Start streaming chat - tokens sent via MethodChannel push
  Future<void> startStreamingChat(String text) async {
    // Cancel any existing stream
    await _cancelCurrentStream();

    // Get user location
    final location = await LocationService.getCurrentLocation();

    // Start streaming and forward tokens to native
    final tokenStream = _aiService.streamChat(
      text,
      userLat: location?.latitude,
      userLon: location?.longitude,
    );

    _currentStreamSubscription = tokenStream.listen(
      (token) {
        _pushTokenToNative(token);
      },
      onError: (error) {
        _pushStreamError(error.toString());
      },
      onDone: () {
        final isVerified = _aiService.lastResponseWasVerified;
        _pushStreamDone(isVerified ? 'verified' : 'unverified');
      },
    );
  }

  /// Cancel current streaming
  Future<void> _cancelCurrentStream() async {
    await _currentStreamSubscription?.cancel();
    _currentStreamSubscription = null;
  }

  /// Generate situational awareness summary from mesh data
  Future<String> generateAwarenessSummary() async {
    final reports = _meshService.reports;
    final broadcasts = _meshService.messages.map((m) => m.body).toList();
    return await _aiService.generateAwarenessSummary(reports, broadcasts);
  }

  // ============================================================
  // MESH METHODS
  // ============================================================

  /// Start the BLE mesh network
  Future<void> startMesh() async {
    await _meshService.start();
    _connectionStatusController.add('connected');
  }

  /// Stop the mesh network
  Future<void> stopMesh() async {
    await _meshService.stop();
    _connectionStatusController.add('disconnected');
  }

  /// Send SOS emergency broadcast
  Future<void> sendSOS({String? description}) async {
    final location = await LocationService.getCurrentLocation();

    final report = EmergencyReport(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      ts: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      lat: location?.latitude ?? 0,
      lng: location?.longitude ?? 0,
      acc: location?.accuracy ?? 0,
      type: 'medical', // Default SOS type
      urg: 5, // Maximum urgency
      haz: [],
      desc: description ?? 'SOS - Emergency assistance needed',
      src: _meshService.deviceId,
      hops: 0,
      ttl: 10,
    );

    await _meshService.broadcastReport(report);
  }

  /// Send a broadcast message to nearby devices (DEPRECATED)
  Future<void> sendBroadcast(String message) async {
    print(
      '[PlatformBridge] sendBroadcast is deprecated and no longer supported in P2P chat mode.',
    );
  }

  /// Send direct message to specific device
  Future<void> sendDirectMessage(String peerId, String message) async {
    final msg = MeshMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      ts: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      src: _meshService.deviceId,
      name: _meshService.displayName,
      to: peerId,
      body: message,
      hops: 0,
      ttl: 10,
    );
    final success = await _meshService.sendDirectMessage(peerId, msg);
    if (!success) {
      print('[PlatformBridge] Failed to send DM to $peerId');
    }
  }

  /// Get all received reports
  List<Map<String, dynamic>> getReports() {
    return _meshService.reports.map((r) => r.toJson()).toList();
  }

  /// Get all broadcast messages (now returns all direct messages)
  List<Map<String, dynamic>> getBroadcasts() {
    return _meshService.messages.map((m) => m.toJson()).toList();
  }

  /// Get list of nearby peers
  List<Map<String, dynamic>> getPeers() {
    return _meshService.peers
        .map(
          (p) => {
            'id': p.deviceId,
            'name': p.displayName,
            'lastSeen': p.lastSeen.millisecondsSinceEpoch,
          },
        )
        .toList();
  }

  // ============================================================
  // SETTINGS
  // ============================================================

  /// Enable/disable background relay mode
  Future<void> setRelayEnabled(bool enabled) async {
    await _meshService.setRelayEnabled(enabled);
  }

  bool get isRelayEnabled => _meshService.isRelayEnabled;

  /// Set display name for mesh messages
  Future<void> setDisplayName(String name) async {
    await _meshService.setDisplayName(name);
  }

  String get displayName => _meshService.displayName;

  // ============================================================
  // PLATFORM CHANNEL HANDLING (for native UI)
  // ============================================================

  void _setupMethodChannel() {
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        // Initialization
        case 'initialize':
          await initialize();
          return {'success': true};

        // AI methods
        case 'transcribe':
          final path = call.arguments['audioPath'] as String;
          final result = await transcribe(path);
          return {'text': result};

        case 'chat':
          final text = call.arguments['text'] as String;
          final extract = call.arguments['extractReport'] as bool? ?? false;
          final extractAndBroadcast =
              call.arguments['extractAndBroadcast'] as bool? ?? false;
          return await chat(
            text,
            extractReport: extract,
            extractAndBroadcast: extractAndBroadcast,
          );

        case 'extractAndBroadcast':
          final text = call.arguments['text'] as String;
          final result = await extractAndBroadcastFromText(text);
          return {'extraction': result};

        case 'startStreamingChat':
          final text = call.arguments['text'] as String;
          await startStreamingChat(text);
          return {'success': true};

        case 'cancelStreamingChat':
          await _cancelCurrentStream();
          return {'success': true};

        case 'generateAwarenessSummary':
          final summary = await generateAwarenessSummary();
          return {'summary': summary};

        // Mesh methods
        case 'startMesh':
          await startMesh();
          return {'success': true};

        case 'stopMesh':
          await stopMesh();
          return {'success': true};

        case 'sendSOS':
          final desc = call.arguments['description'] as String?;
          await sendSOS(description: desc);
          return {'success': true};

        case 'sendBroadcast':
          final msg = call.arguments['message'] as String;
          await sendBroadcast(msg);
          return {'success': true};

        case 'sendDirectMessage':
          final peerId = call.arguments['peerId'] as String;
          final msg = call.arguments['message'] as String;
          await sendDirectMessage(peerId, msg);
          return {'success': true};

        case 'getReports':
          return {'reports': getReports()};

        case 'getBroadcasts':
          return {'broadcasts': getBroadcasts()};

        case 'getPeers':
          return {'peers': getPeers()};

        // Settings
        case 'setRelayEnabled':
          final enabled = call.arguments['enabled'] as bool;
          await setRelayEnabled(enabled);
          return {'success': true};

        case 'setDisplayName':
          final name = call.arguments['name'] as String;
          await setDisplayName(name);
          return {'success': true};

        case 'getState':
          return {
            'isInitialized': isInitialized,
            'isAiReady': isAiReady,
            'isSttReady': isSttReady,
            'isMeshConnected': isMeshConnected,
            'peerCount': peerCount,
            'isRelayEnabled': isRelayEnabled,
            'displayName': displayName,
          };

        default:
          throw PlatformException(
            code: 'NOT_IMPLEMENTED',
            message: 'Method ${call.method} not implemented',
          );
      }
    });
  }

  /// Setup streaming - we use MethodChannel push for simplicity
  void _setupStreamChannel() {
    // Streaming uses MethodChannel push (invokeMethod from Dart to Swift)
    // No EventChannel setup needed since we're pushing tokens
  }

  /// Push event to native side
  void _pushToNative(String method, Map<String, dynamic> arguments) {
    _channel.invokeMethod(method, arguments).catchError((e) {
      // Native side might not be listening - that's OK
    });
  }

  /// Stream tokens to native side via method channel push
  void _pushTokenToNative(String token) {
    _channel.invokeMethod('onStreamToken', {'token': token}).catchError((e) {
      // Native side might not be listening
    });
  }

  void _pushStreamDone(String confidence) {
    _channel
        .invokeMethod('onStreamDone', {'confidence': confidence})
        .catchError((e) {
          // Native side might not be listening
        });
  }

  void _pushStreamError(String error) {
    _channel.invokeMethod('onStreamError', {'error': error}).catchError((e) {
      // Native side might not be listening
    });
  }

  /// Cleanup
  Future<void> dispose() async {
    _aiService.dispose();
    await _meshService.stop();
    await _initProgressController.close();
    await _meshPacketController.close();
    await _peerCountController.close();
    await _connectionStatusController.close();
  }
}
