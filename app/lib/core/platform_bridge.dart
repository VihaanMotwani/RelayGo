import 'dart:async';
import 'package:flutter/services.dart';

import '../models/emergency_report.dart';
import '../models/mesh_message.dart';
import '../services/ai/ai_service.dart';
import '../services/ai/ai_event_generator.dart';
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
    _setupAiEventGenerator();
  }

  // Services
  final AiService _aiService = AiService();
  final MeshService _meshService = MeshService();
  late final AiEventGenerator _aiEventGenerator;

  // Platform channel for native UI communication
  static const _channel = MethodChannel('com.relaygo/bridge');

  // Current streaming state
  StreamSubscription<String>? _currentStreamSubscription;

  // Stream controllers for pushing events to listeners (Flutter UI or native)
  final _initProgressController = StreamController<String>.broadcast();
  final _meshPacketController = StreamController<Map<String, dynamic>>.broadcast();
  final _peerCountController = StreamController<int>.broadcast();
  final _connectionStatusController = StreamController<String>.broadcast();

  // Public streams for Flutter UI
  Stream<String> get initProgress => _initProgressController.stream;
  Stream<Map<String, dynamic>> get onMeshPacket => _meshPacketController.stream;
  Stream<int> get onPeerCountChanged => _peerCountController.stream;
  Stream<String> get onConnectionStatusChanged => _connectionStatusController.stream;

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

    _meshService.onPeerCountChanged.listen((count) {
      _peerCountController.add(count);
      _pushToNative('onPeerCountChanged', {'count': count});
    });

    _meshService.onConnectionStatusChanged.listen((status) {
      _connectionStatusController.add(status);
      _pushToNative('onConnectionStatus', {'status': status});
    });

    _isInitialized = true;
    _initProgressController.add('Ready');
  }

  /// Setup AI event generator after services are created
  void _setupAiEventGenerator() {
    _aiEventGenerator = AiEventGenerator(
      aiService: _aiService,
      meshService: _meshService,
    );
    // Wire up AI event generator to mesh service for auto-analysis
    _meshService.setAiEventGenerator(_aiEventGenerator);
  }

  // ============================================================
  // AI METHODS
  // ============================================================

  /// Transcribe audio file to text
  /// Also attempts to extract and broadcast emergency data if detected
  Future<String> transcribe(String audioPath) async {
    // Fire-and-forget event extraction (runs in background)
    // Ignore result - we only care about transcription for immediate return
    _aiEventGenerator.transcribeAndExtractEvent(audioPath).then((_) {
      // Success - extraction and broadcast completed
    }).catchError((e) {
      print('[PlatformBridge] Voice extraction failed: $e');
    });

    // Return transcription immediately
    return await _aiService.transcribe(audioPath);
  }

  /// Send message to AI and get response
  /// If extractAndBroadcast is true and mesh is connected, extracts emergency data and broadcasts it
  Future<Map<String, dynamic>> chat(String text, {bool extractReport = false, bool extractAndBroadcast = false}) async {
    // Use AI event generator for chat with extraction
    if (extractAndBroadcast && _meshService.isConnected) {
      final result = await _aiEventGenerator.chatAndExtractEvent(
        text,
        extractAndBroadcast: true,
      );

      return {
        'text': result.aiResponse,
        'confidence': result.confidence.name,
        'extraction': result.extractedReport != null
            ? {
                'type': result.extractedReport!.type,
                'urgency': result.extractedReport!.urg,
                'hazards': result.extractedReport!.haz,
                'description': result.extractedReport!.desc,
              }
            : null,
        'broadcast': result.wasBroadcast,
      };
    }

    // Otherwise use AI service directly (no extraction)
    final location = await LocationService.getCurrentLocation();
    final response = await _aiService.chat(
      text,
      extractReport: extractReport,
      userLat: location?.latitude,
      userLon: location?.longitude,
    );

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

  /// Extract emergency data from text and broadcast if significant
  /// Used for Nearby chat messages to auto-detect emergencies
  Future<Map<String, dynamic>?> extractAndBroadcastFromText(String text) async {
    if (!_meshService.isConnected || !_aiService.isReady) {
      return null;
    }

    final result = await _aiEventGenerator.chatAndExtractEvent(
      text,
      extractAndBroadcast: true,
    );

    if (result.extractedReport != null) {
      return {
        'type': result.extractedReport!.type,
        'urgency': result.extractedReport!.urg,
        'hazards': result.extractedReport!.haz,
        'description': result.extractedReport!.desc,
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
    final msg = await _aiEventGenerator.generateAwarenessBroadcast();
    if (msg != null && _meshService.isConnected) {
      await _meshService.broadcastMessage(msg);
      return msg.body;
    }
    return 'Unable to generate awareness summary';
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

  /// Send a broadcast message to nearby devices
  Future<void> sendBroadcast(String message) async {
    final msg = MeshMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      ts: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      src: _meshService.deviceId,
      name: _meshService.displayName,
      to: null, // Broadcast
      body: message,
      hops: 0,
      ttl: 10,
    );
    await _meshService.broadcastMessage(msg);
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
    await _meshService.broadcastMessage(msg);
  }

  /// Get all received reports
  List<Map<String, dynamic>> getReports() {
    return _meshService.reports.map((r) => r.toJson()).toList();
  }

  /// Get all broadcast messages
  List<Map<String, dynamic>> getBroadcasts() {
    return _meshService.broadcastMessages.map((m) => m.toJson()).toList();
  }

  /// Get list of nearby peers
  List<Map<String, dynamic>> getPeers() {
    return _meshService.peers.map((p) => {
      'id': p.deviceId,
      'name': p.displayName,
      'lastSeen': p.lastSeen.millisecondsSinceEpoch,
    }).toList();
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
          final extractAndBroadcast = call.arguments['extractAndBroadcast'] as bool? ?? false;
          return await chat(text, extractReport: extract, extractAndBroadcast: extractAndBroadcast);

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
    _channel.invokeMethod('onStreamDone', {'confidence': confidence}).catchError((e) {
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
