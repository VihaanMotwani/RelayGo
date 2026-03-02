import '../../models/chat_message.dart';
import '../../models/emergency_report.dart';
import '../../models/mesh_message.dart';
import '../location_service.dart';
import 'ai_service.dart';
import 'intent_filter.dart';

/// High-level event generator that wraps AiService and provides APIs
/// for generating mesh events from various sources:
/// - User chat conversations
/// - Incoming mesh messages (auto-analysis)
/// - Voice transcriptions
/// - Situational awareness summaries
class AiEventGenerator {
  final AiService _aiService;
  late final dynamic _meshService; // late to avoid circular dependency

  AiEventGenerator({
    required AiService aiService,
    required dynamic meshService,
  })  : _aiService = aiService,
        _meshService = meshService;

  /// API 1: Chat-to-Event (existing flow, refactored)
  /// Processes user text, optionally extracts emergency data, and broadcasts to mesh
  Future<ChatWithEvent> chatAndExtractEvent(
    String userText, {
    bool extractAndBroadcast = false,
  }) async {
    // Get user location for context
    final location = await LocationService.getCurrentLocation();

    // Chat with AI
    final response = await _aiService.chat(
      userText,
      extractReport: extractAndBroadcast,
      userLat: location?.latitude,
      userLon: location?.longitude,
    );

    EmergencyReport? extractedReport;
    bool wasBroadcast = false;

    // If extraction succeeded and mesh is connected, broadcast the report
    if (extractAndBroadcast &&
        _meshService.isConnected &&
        response.extraction != null &&
        location != null) {
      extractedReport = EmergencyReport.fromAiExtraction(
        extraction: response.extraction!,
        location: location,
        deviceId: _meshService.deviceId,
      );

      // Validate before broadcasting
      if (extractedReport.isValidForBroadcast()) {
        await _meshService.broadcastReport(extractedReport);
        wasBroadcast = true;
        print(
          '[AiEventGenerator] Broadcast report: ${extractedReport.type} urg=${extractedReport.urg}',
        );
      } else {
        print(
          '[AiEventGenerator] Skipping broadcast - report failed validation',
        );
        extractedReport = null;
      }
    }

    return ChatWithEvent(
      aiResponse: response.text,
      confidence: response.confidence,
      extractedReport: extractedReport,
      wasBroadcast: wasBroadcast,
    );
  }

  /// API 2: Auto-analyze incoming messages
  /// Processes incoming mesh messages to extract structured emergency data
  /// Only analyzes if IntentFilter detects emergency keywords (efficient)
  Future<EmergencyReport?> analyzeIncomingMessage(MeshMessage msg) async {
    // Pre-filter: only analyze if likely emergency
    if (!IntentFilter.isLikelyEmergency(msg.body)) {
      return null;
    }

    print(
      '[AiEventGenerator] Analyzing incoming message for emergency extraction',
    );

    // Get location (use message source location if available, otherwise current)
    final location = await LocationService.getCurrentLocation();
    if (location == null) {
      print('[AiEventGenerator] No location available, skipping extraction');
      return null;
    }

    // Extract emergency data
    final response = await _aiService.chat(
      msg.body,
      extractReport: true,
      userLat: location.latitude,
      userLon: location.longitude,
    );

    if (response.extraction == null) {
      print('[AiEventGenerator] No extraction from incoming message');
      return null;
    }

    // Create report from extraction
    final report = EmergencyReport.fromAiExtraction(
      extraction: response.extraction!,
      location: location,
      deviceId: _meshService.deviceId,
      sourceMessageId: msg.id, // Track source for deduplication
    );

    return report;
  }

  /// API 3: Generate situational awareness summary
  /// Creates a broadcast message summarizing current mesh state
  Future<MeshMessage?> generateAwarenessBroadcast() async {
    final reports = _meshService.reports;
    final messages = _meshService.broadcastMessages.map((m) => m.body).toList();

    final summary = await _aiService.generateAwarenessSummary(reports, messages);

    // Create broadcast message with summary
    final msg = MeshMessage(
      ts: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      src: _meshService.deviceId,
      name: '${_meshService.displayName} (AI Summary)',
      to: null, // Broadcast to all
      body: summary,
      hops: 0,
      ttl: 10,
    );

    return msg;
  }

  /// API 4: Voice-to-Event (enhanced flow)
  /// Transcribes audio and extracts emergency data if present
  Future<VoiceTranscriptionResult> transcribeAndExtractEvent(
    String audioPath,
  ) async {
    // Transcribe audio
    final transcription = await _aiService.transcribe(audioPath);

    // Check if transcription succeeded
    if (transcription.isEmpty || transcription.startsWith('[')) {
      return VoiceTranscriptionResult(
        transcription: transcription,
        extractedReport: null,
        wasBroadcast: false,
      );
    }

    // Check if likely emergency
    if (!IntentFilter.isLikelyEmergency(transcription)) {
      return VoiceTranscriptionResult(
        transcription: transcription,
        extractedReport: null,
        wasBroadcast: false,
      );
    }

    // Get location
    final location = await LocationService.getCurrentLocation();
    if (location == null) {
      return VoiceTranscriptionResult(
        transcription: transcription,
        extractedReport: null,
        wasBroadcast: false,
      );
    }

    // Extract emergency data
    final response = await _aiService.chat(
      transcription,
      extractReport: true,
      userLat: location.latitude,
      userLon: location.longitude,
    );

    if (response.extraction == null) {
      return VoiceTranscriptionResult(
        transcription: transcription,
        extractedReport: null,
        wasBroadcast: false,
      );
    }

    // Create and broadcast report
    final report = EmergencyReport.fromAiExtraction(
      extraction: response.extraction!,
      location: location,
      deviceId: _meshService.deviceId,
    );

    bool wasBroadcast = false;
    if (report.isValidForBroadcast() && _meshService.isConnected) {
      await _meshService.broadcastReport(report);
      wasBroadcast = true;
      print(
        '[AiEventGenerator] Broadcast voice-extracted report: ${report.type} urg=${report.urg}',
      );
    }

    return VoiceTranscriptionResult(
      transcription: transcription,
      extractedReport: wasBroadcast ? report : null,
      wasBroadcast: wasBroadcast,
    );
  }

  /// Get the underlying AI service (for direct access if needed)
  AiService get aiService => _aiService;
}

/// Result of chat with event extraction
class ChatWithEvent {
  final String aiResponse;
  final ConfidenceLevel confidence;
  final EmergencyReport? extractedReport; // If urgent
  final bool wasBroadcast; // If sent to mesh

  ChatWithEvent({
    required this.aiResponse,
    required this.confidence,
    this.extractedReport,
    required this.wasBroadcast,
  });
}

/// Result of voice transcription with optional event extraction
class VoiceTranscriptionResult {
  final String transcription;
  final EmergencyReport? extractedReport;
  final bool wasBroadcast;

  VoiceTranscriptionResult({
    required this.transcription,
    this.extractedReport,
    required this.wasBroadcast,
  });
}
