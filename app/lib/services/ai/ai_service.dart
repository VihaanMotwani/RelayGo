import 'dart:async';

import 'package:cactus/cactus.dart';

import '../../core/constants.dart';
import '../../models/chat_message.dart' as app;
import '../../models/emergency_report.dart';
import 'knowledge_loader.dart';
import 'location_service.dart';
import 'prompts.dart';

class AiExtraction {
  final String type;
  final int urgency;
  final List<String> hazards;
  final String description;

  AiExtraction({
    required this.type,
    required this.urgency,
    required this.hazards,
    required this.description,
  });
}

class AiResponse {
  final String text;
  final app.ConfidenceLevel confidence;
  final AiExtraction? extraction;

  AiResponse({
    required this.text,
    required this.confidence,
    this.extraction,
  });
}

/// Streaming response that yields tokens as they arrive
class AiStreamResponse {
  final Stream<String> tokenStream;
  final Future<app.ConfidenceLevel> confidence;

  AiStreamResponse({
    required this.tokenStream,
    required this.confidence,
  });
}

class AiService {
  CactusLM? _lm;
  CactusSTT? _stt;
  CactusRAG? _rag;
  final LocationService _locationService = LocationService();
  bool _lmReady = false;
  bool _sttReady = false;
  String? _initError;

  bool get isReady => _lmReady;
  bool get isSttReady => _sttReady;
  bool get isLocationReady => _locationService.isInitialized;
  String? get initError => _initError;
  LocationService get locationService => _locationService;

  final _initController = StreamController<String>.broadcast();
  Stream<String> get initProgress => _initController.stream;

  Future<void> initialize() async {
    try {
      _lm = CactusLM(enableToolFiltering: true);
      _stt = CactusSTT();
      _rag = CactusRAG();

      // Download and init LLM
      _initController.add('Downloading language model...');
      await _lm!.downloadModel(
        model: AiConfig.modelSlug,
        downloadProcessCallback: (progress, status, isError) {
          if (progress != null) {
            _initController.add('LLM: ${(progress * 100).toStringAsFixed(0)}%');
          }
        },
      );

      _initController.add('Initializing language model...');
      try {
        await _lm!.initializeModel(
          params: CactusInitParams(model: AiConfig.modelSlug),
        );
        _lmReady = true;
      } catch (e) {
        print('[AiService] LLM initialization failed: $e');
        _initError = 'LLM init failed: $e';
        _initController.add('LLM initialization failed (running without AI)');
        // Continue without LLM - don't throw
      }

      // Load RAG knowledge base (only if LLM ready)
      if (_lmReady) {
        _initController.add('Loading knowledge base...');
        try {
          await KnowledgeLoader.loadIntoRag(_rag!, _lm!);
        } catch (e) {
          print('[AiService] RAG loading failed: $e');
          // Continue without RAG
        }
      }

      // Load location data (independent of LLM)
      _initController.add('Loading location data...');
      try {
        await _locationService.initialize();
      } catch (e) {
        print('[AiService] Location service init failed: $e');
        // Continue without location service
      }

      // Download and init STT
      _initController.add('Downloading speech model...');
      try {
        await _stt!.downloadModel(
          model: 'whisper-tiny',
          downloadProcessCallback: (progress, status, isError) {
            if (progress != null) {
              _initController.add('STT: ${(progress * 100).toStringAsFixed(0)}%');
            }
          },
        );

        _initController.add('Initializing speech model...');
        await _stt!.initializeModel(
          params: CactusInitParams(model: 'whisper-tiny'),
        );
        _sttReady = true;
      } catch (e) {
        print('[AiService] STT initialization failed: $e');
        // Continue without STT
      }

      if (_lmReady) {
        _initController.add('Ready');
      } else {
        _initController.add('Ready (AI unavailable - other features work)');
      }
    } catch (e) {
      print('[AiService] Initialization error: $e');
      _initError = e.toString();
      _initController.add('AI initialization failed: $e');
      // Don't rethrow - let the app continue without AI
    }
  }

  Future<String> transcribe(String audioPath) async {
    if (!_sttReady || _stt == null) {
      return '[Voice transcription unavailable]';
    }

    try {
      final result = await _stt!.transcribe(
        audioFilePath: audioPath,
      );

      if (!result.success) {
        return '[Transcription failed]';
      }

      return result.text;
    } catch (e) {
      print('[AiService] Transcription error: $e');
      return '[Transcription error]';
    }
  }

  Future<AiResponse> chat(
    String userText, {
    bool extractReport = false,
    double? userLat,
    double? userLon,
    EmergencyType? emergencyType,
  }) async {
    // If AI not ready, return a helpful fallback response
    if (!_lmReady || _lm == null) {
      return AiResponse(
        text: _getFallbackResponse(userText),
        confidence: app.ConfidenceLevel.unverified,
      );
    }

    try {
      // Search RAG for relevant knowledge
      String ragContext = '';
      if (_rag != null) {
        try {
          ragContext = await KnowledgeLoader.searchKnowledge(_rag!, userText);
        } catch (e) {
          print('[AiService] RAG search failed: $e');
        }
      }

      // Get nearby resources if location provided
      String locationContext = '';
      if (userLat != null && userLon != null && _locationService.isInitialized) {
        final eType = emergencyType ?? _inferEmergencyType(userText);
        locationContext = _locationService.formatForLLM(
          lat: userLat,
          lon: userLon,
          emergencyType: eType,
          maxPerType: 3,
        );
      }

      // Build messages
      String fullSystemPrompt = systemPrompt;
      if (ragContext.isNotEmpty) {
        fullSystemPrompt += '\n\nRELEVANT VERIFIED PROCEDURES:\n$ragContext';
      }
      if (locationContext.isNotEmpty) {
        fullSystemPrompt += '\n\n$locationContext';
      }
      if (extractReport) {
        fullSystemPrompt += '\n\n$extractionPrompt';
      }

      final messages = [
        ChatMessage(content: fullSystemPrompt, role: 'system'),
        ChatMessage(content: userText, role: 'user'),
      ];

      final params = CactusCompletionParams(
        tools: extractReport ? [extractEmergencyTool] : [],
        temperature: AiConfig.temperature,
        maxTokens: AiConfig.maxTokens,
      );

      final result = await _lm!.generateCompletion(
        messages: messages,
        params: params,
      );

      if (!result.success) {
        return AiResponse(
          text: 'I\'m having trouble processing your request. Please try again.',
          confidence: app.ConfidenceLevel.unverified,
        );
      }

      // Check for tool calls
      AiExtraction? extraction;
      if (result.toolCalls.isNotEmpty) {
        final toolCall = result.toolCalls.first;
        if (toolCall.name == 'extract_emergency') {
          final args = toolCall.arguments;
          extraction = AiExtraction(
            type: args['type']?.toString() ?? 'other',
            urgency: int.tryParse(args['urgency']?.toString() ?? '3') ?? 3,
            hazards: (args['hazards']?.toString() ?? '')
                .split(',')
                .map((s) => s.trim())
                .where((s) => s.isNotEmpty)
                .toList(),
            description: args['description']?.toString() ?? userText,
          );
        }
      }

      // Determine confidence level
      app.ConfidenceLevel confidence = app.ConfidenceLevel.unverified;
      if (ragContext.isNotEmpty) {
        confidence = app.ConfidenceLevel.verified;
      }

      return AiResponse(
        text: result.response,
        confidence: confidence,
        extraction: extraction,
      );
    } catch (e) {
      print('[AiService] Chat error: $e');
      return AiResponse(
        text: _getFallbackResponse(userText),
        confidence: app.ConfidenceLevel.unverified,
      );
    }
  }

  /// Infer emergency type from user text for location filtering.
  EmergencyType _inferEmergencyType(String text) {
    final lower = text.toLowerCase();
    if (lower.contains('fire') || lower.contains('smoke') || lower.contains('burning')) {
      return EmergencyType.fire;
    }
    if (lower.contains('hurt') || lower.contains('bleeding') || lower.contains('injured') ||
        lower.contains('heart') || lower.contains('breathing') || lower.contains('medical') ||
        lower.contains('sick') || lower.contains('pain')) {
      return EmergencyType.medical;
    }
    if (lower.contains('earthquake') || lower.contains('collapse') || lower.contains('building')) {
      return EmergencyType.structural;
    }
    if (lower.contains('flood') || lower.contains('water') || lower.contains('drowning')) {
      return EmergencyType.flood;
    }
    if (lower.contains('chemical') || lower.contains('gas') || lower.contains('hazmat') ||
        lower.contains('toxic') || lower.contains('spill')) {
      return EmergencyType.hazmat;
    }
    return EmergencyType.other;
  }

  /// Fallback responses when AI is not available
  String _getFallbackResponse(String text) {
    final lower = text.toLowerCase();

    if (lower.contains('fire') || lower.contains('smoke')) {
      return 'FIRE SAFETY: Get out immediately. Stay low if there\'s smoke. Call 911 once safe. Don\'t use elevators. Meet at your designated meeting point.\n\n[AI offline - showing cached guidance]';
    }

    if (lower.contains('hurt') || lower.contains('bleeding') || lower.contains('injured')) {
      return 'FIRST AID: Apply direct pressure to bleeding with a clean cloth. Keep the person still and calm. Call 911 for serious injuries. Don\'t move them unless in immediate danger.\n\n[AI offline - showing cached guidance]';
    }

    if (lower.contains('earthquake')) {
      return 'EARTHQUAKE: Drop, Cover, Hold On. Stay away from windows and heavy objects. After shaking stops, check for injuries and exit if safe. Be prepared for aftershocks.\n\n[AI offline - showing cached guidance]';
    }

    if (lower.contains('flood') || lower.contains('water')) {
      return 'FLOOD: Move to higher ground immediately. Never walk or drive through flood water. 6 inches can knock you down, 2 feet can float a car. Avoid downed power lines.\n\n[AI offline - showing cached guidance]';
    }

    return 'AI assistant is currently unavailable. For emergencies, call 911.\n\nBasic tips:\n- Stay calm and assess the situation\n- Move to a safe location if needed\n- Help others if you can do so safely\n- Wait for emergency services\n\n[AI offline - mesh networking and SOS features still work]';
  }

  /// Stream chat response token by token
  Stream<String> streamChat(
    String userText, {
    double? userLat,
    double? userLon,
    EmergencyType? emergencyType,
  }) async* {
    // If AI not ready, yield fallback response
    if (!_lmReady || _lm == null) {
      yield _getFallbackResponse(userText);
      return;
    }

    try {
      // Search RAG for relevant knowledge
      String ragContext = '';
      if (_rag != null) {
        try {
          ragContext = await KnowledgeLoader.searchKnowledge(_rag!, userText);
        } catch (e) {
          print('[AiService] RAG search failed: $e');
        }
      }

      // Track RAG usage for confidence level
      _lastResponseUsedRag = ragContext.isNotEmpty;

      // Get nearby resources if location provided
      String locationContext = '';
      if (userLat != null && userLon != null && _locationService.isInitialized) {
        final eType = emergencyType ?? _inferEmergencyType(userText);
        locationContext = _locationService.formatForLLM(
          lat: userLat,
          lon: userLon,
          emergencyType: eType,
          maxPerType: 3,
        );
      }

      // Build system prompt with context
      String fullSystemPrompt = systemPrompt;
      if (ragContext.isNotEmpty) {
        fullSystemPrompt += '\n\nRELEVANT VERIFIED PROCEDURES:\n$ragContext';
      }
      if (locationContext.isNotEmpty) {
        fullSystemPrompt += '\n\n$locationContext';
      }

      final messages = [
        ChatMessage(content: fullSystemPrompt, role: 'system'),
        ChatMessage(content: userText, role: 'user'),
      ];

      final params = CactusCompletionParams(
        temperature: AiConfig.temperature,
        maxTokens: AiConfig.maxTokens,
      );

      // Use streaming API
      final streamedResult = await _lm!.generateCompletionStream(
        messages: messages,
        params: params,
      );

      // Yield tokens as they arrive
      await for (final chunk in streamedResult.stream) {
        yield chunk;
      }
    } catch (e) {
      print('[AiService] Stream chat error: $e');
      _lastResponseUsedRag = false;
      yield _getFallbackResponse(userText);
    }
  }

  /// Check if last response used RAG (for confidence level)
  bool _lastResponseUsedRag = false;
  bool get lastResponseWasVerified => _lastResponseUsedRag;

  Future<String> generateAwarenessSummary(
    List<EmergencyReport> reports,
    List<String> broadcastMessages,
  ) async {
    if (!_lmReady || _lm == null) {
      // Return a simple text summary without AI
      final buffer = StringBuffer();
      buffer.writeln('SITUATIONAL SUMMARY (AI unavailable)\n');

      if (reports.isEmpty && broadcastMessages.isEmpty) {
        buffer.writeln('No reports or messages received yet.');
      } else {
        if (reports.isNotEmpty) {
          buffer.writeln('${reports.length} emergency report(s):');
          for (final report in reports.take(5)) {
            buffer.writeln('- [${report.type.toUpperCase()}] ${report.desc}');
          }
        }
        if (broadcastMessages.isNotEmpty) {
          buffer.writeln('\n${broadcastMessages.length} broadcast message(s):');
          for (final msg in broadcastMessages.take(5)) {
            buffer.writeln('- $msg');
          }
        }
      }
      return buffer.toString();
    }

    try {
      final buffer = StringBuffer(awarenessPrompt);

      // Add reports
      buffer.writeln('\nEMERGENCY REPORTS (${reports.length}):');
      for (final report in reports.take(20)) {
        buffer.writeln('- [${report.type.toUpperCase()}] Urgency ${report.urg}/5: ${report.desc} (${report.hops} hops, lat:${report.lat}, lng:${report.lng})');
      }

      // Add broadcast messages
      if (broadcastMessages.isNotEmpty) {
        buffer.writeln('\nBROADCAST MESSAGES (${broadcastMessages.length}):');
        for (final msg in broadcastMessages.take(20)) {
          buffer.writeln('- $msg');
        }
      }

      final result = await _lm!.generateCompletion(
        messages: [
          ChatMessage(content: buffer.toString(), role: 'user'),
        ],
        params: CactusCompletionParams(
          temperature: AiConfig.temperature,
          maxTokens: AiConfig.maxTokens,
        ),
      );

      return result.success
          ? result.response
          : 'Unable to generate summary. Check reports list for raw data.';
    } catch (e) {
      print('[AiService] Summary generation error: $e');
      return 'Unable to generate AI summary. ${reports.length} reports and ${broadcastMessages.length} messages received.';
    }
  }

  void dispose() {
    _lm?.unload();
    _stt?.unload();
    _rag?.close();
    _initController.close();
  }
}
