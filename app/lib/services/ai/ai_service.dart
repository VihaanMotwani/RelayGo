import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cactus/cactus.dart';

import '../../core/constants.dart';
import '../../models/chat_message.dart' as app;
import '../../models/emergency_report.dart';
import 'intent_filter.dart';
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
  String? _sttInitError;
  String? _activeSttModel;

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
      await _initializeSttWithFallback();

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
      if (_sttInitError != null) {
        return '[Voice transcription unavailable: $_sttInitError]';
      }
      return '[Voice transcription unavailable: speech model not initialized]';
    }

    if (!File(audioPath).existsSync()) {
      return '[Voice transcription unavailable: audio file missing]';
    }

    try {
      // The C++ WAV parser inside Cactus can fail on iOS AVAudioRecorder files
      // ("Missing fmt chunk"). Read the file in Dart, locate the raw PCM bytes
      // in the `data` chunk, and pass them via the audioStream API instead.
      final pcm = await _wavDataChunk(audioPath);
      if (pcm == null || pcm.isEmpty) {
        return '[Transcription failed]';
      }

      final controller = StreamController<Uint8List>();
      final future = _stt!.transcribe(audioStream: controller.stream);
      controller.add(pcm);
      await controller.close();

      final result = await future;
      if (!result.success) {
        return '[Transcription failed: model returned unsuccessful result]';
      }

      final text = result.text.trim();
      if (text.isEmpty) {
        return '[Transcription failed: no speech detected]';
      }

      return text;
    } catch (e) {
      print('[AiService] Transcription error: $e');
      return '[Transcription error: $e]';
    }
  }

  /// Parses a RIFF/WAV file and returns the raw bytes of its `data` chunk
  /// (unsigned 8-bit view of signed 16-bit LE PCM samples).
  /// Falls back to skipping the standard 44-byte header if no chunk is found.
  Future<Uint8List?> _wavDataChunk(String path) async {
    try {
      final bytes = await File(path).readAsBytes();
      if (bytes.length < 12) return null;

      // Verify RIFF magic ("RIFF")
      if (bytes[0] != 0x52 || bytes[1] != 0x49 ||
          bytes[2] != 0x46 || bytes[3] != 0x46) {
        return bytes.length > 44 ? bytes.sublist(44) : null;
      }

      // Walk chunks after the 12-byte RIFF/WAVE preamble
      int offset = 12;
      while (offset + 8 <= bytes.length) {
        final id = String.fromCharCodes(bytes.sublist(offset, offset + 4));
        final size = bytes[offset + 4] |
            (bytes[offset + 5] << 8) |
            (bytes[offset + 6] << 16) |
            (bytes[offset + 7] << 24);

        if (id == 'data') {
          final end = (offset + 8 + size).clamp(0, bytes.length);
          return bytes.sublist(offset + 8, end);
        }

        offset += 8 + size + (size & 1); // WAV chunks are word-aligned
      }

      return bytes.length > 44 ? bytes.sublist(44) : null;
    } catch (e) {
      print('[AiService] WAV parse error: $e');
      return null;
    }
  }

  Future<void> _initializeSttWithFallback() async {
    if (_stt == null) return;

    const candidates = ['whisper-medium', 'whisper-tiny'];
    String? lastError;

    for (final model in candidates) {
      try {
        _initController.add('Downloading speech model ($model)...');
        await _stt!.downloadModel(
          model: model,
          downloadProcessCallback: (progress, status, isError) {
            if (progress != null) {
              _initController
                  .add('STT [$model]: ${(progress * 100).toStringAsFixed(0)}%');
            }
          },
        );

        _initController.add('Initializing speech model ($model)...');
        await _stt!.initializeModel(
          params: CactusInitParams(model: model),
        );

        _activeSttModel = model;
        _sttReady = true;
        _sttInitError = null;
        _initController.add('Speech model ready ($model)');
        return;
      } catch (e) {
        lastError = e.toString();
        print('[AiService] STT initialization failed for $model: $e');
      }
    }

    _sttReady = false;
    _sttInitError = lastError ?? 'unknown error';
    _initController.add('Speech model unavailable');
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
      // Layer 1: Intent pre-filter — skip extraction tool entirely for
      // non-emergency messages. This reduces false alarms and keeps
      // context shorter for faster inference on the small model.
      final bool shouldExtract =
          extractReport && IntentFilter.isLikelyEmergency(userText);

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

      // Build system prompt. Order matters for small models — most important
      // instruction goes first.
      //
      // Layout:
      //   [1] extraction directive (if needed) — must be seen early
      //   [2] base system prompt
      //   [3] RAG knowledge — injected as the last block so the model quotes it
      //   [4] location context (nearby resources)
      final buffer = StringBuffer();
      if (shouldExtract) {
        buffer.writeln(extractionPrompt);
        buffer.writeln();
      }
      buffer.write(systemPrompt);
      if (ragContext.isNotEmpty) {
        buffer.writeln('\n\n$ragContext');
      }
      if (locationContext.isNotEmpty) {
        buffer.writeln('\n\n$locationContext');
      }
      final String fullSystemPrompt = buffer.toString();

      final messages = [
        ChatMessage(content: fullSystemPrompt, role: 'system'),
        ChatMessage(content: userText, role: 'user'),
      ];

      final params = CactusCompletionParams(
        tools: shouldExtract ? [extractEmergencyTool] : null,
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

      // Parse tool call → AiExtraction
      AiExtraction? extraction;
      if (result.toolCalls.isNotEmpty) {
        final toolCall = result.toolCalls.first;
        if (toolCall.name == 'extract_emergency') {
          final args = toolCall.arguments;
          final type = args['type']?.toString() ?? 'other';
          final urgency =
              int.tryParse(args['urgency']?.toString() ?? '1') ?? 1;
          final hazards = (args['hazards']?.toString() ?? '')
              .split(',')
              .map((s) => s.trim())
              .where((s) => s.isNotEmpty)
              .toList();
          final description =
              args['description']?.toString() ?? userText;

          // Layer 2: Extraction confidence gate — discard low-confidence
          // tool calls before they become broadcast emergency reports.
          //
          // Thresholds:
          //   urgency >= 2   : ignore pure "informational" (urgency=1) reports
          //   type != 'other' OR urgency >= 4 : require a specific type unless
          //                   it's a serious unclassified emergency
          //   description length > 10 : ignore empty/garbage descriptions
          final bool meetsThreshold = urgency >= 2 &&
              (type != 'other' || urgency >= 4) &&
              description.length > 10;

          if (meetsThreshold) {
            extraction = AiExtraction(
              type: type,
              urgency: urgency,
              hazards: hazards,
              description: description,
            );
          }
        }
      }

      // Confidence level: verified if RAG knowledge was used
      final app.ConfidenceLevel confidence = ragContext.isNotEmpty
          ? app.ConfidenceLevel.verified
          : app.ConfidenceLevel.unverified;

      return AiResponse(
        text: _sanitizeAssistantOutput(
          result.response,
          fallback: _getFallbackResponse(userText),
        ),
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

      // Stop sequences that indicate model is done or hallucinating
      final stopPatterns = ['<IM_end>', '<|im_end|>', '<|endoftext|>', 'User:', '\nUser:'];

      // Accumulate full response for sanitization
      var fullResponse = '';
      var shouldStop = false;

      // Collect all tokens first
      await for (final chunk in streamedResult.stream) {
        if (shouldStop) break;

        fullResponse += chunk;

        // Check for stop patterns
        for (final pattern in stopPatterns) {
          if (fullResponse.contains(pattern)) {
            final idx = fullResponse.indexOf(pattern);
            fullResponse = fullResponse.substring(0, idx);
            shouldStop = true;
            break;
          }
        }
      }

      // Now sanitize the complete response and yield character by character for smooth streaming
      final sanitized = _sanitizeForStreaming(fullResponse);

      // Yield in small chunks for smooth streaming effect
      const chunkSize = 3; // Characters per yield
      for (var i = 0; i < sanitized.length; i += chunkSize) {
        final end = (i + chunkSize < sanitized.length) ? i + chunkSize : sanitized.length;
        yield sanitized.substring(i, end);
        // Small delay for smooth visual effect
        await Future.delayed(Duration(milliseconds: 15));
      }
    } catch (e) {
      print('[AiService] Stream chat error: $e');
      _lastResponseUsedRag = false;
      yield _getFallbackResponse(userText);
    }
  }

  /// Lightweight sanitization for individual streaming chunks
  /// Removes special tokens and role prefixes
  String _sanitizeStreamChunk(String chunk) {
    var cleaned = _stripSpecialTokens(chunk);

    // Remove role prefixes that might appear mid-stream
    cleaned = cleaned.replaceAll(
      RegExp(r'^\s*(assistant|system|user)\s*:\s*',
          caseSensitive: false, multiLine: true),
      '',
    );

    return cleaned;
  }

  /// Sanitize complete response for streaming - removes thinking blocks and cleans formatting
  String _sanitizeForStreaming(String text) {
    // Use the full sanitization pipeline
    return _sanitizeAssistantOutput(
      text,
      fallback: "I'm here to help with emergency guidance. Please tell me what happened.",
    );
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
          ? _sanitizeAssistantOutput(
              result.response,
              fallback:
                  'Unable to generate summary. Check reports list for raw data.',
            )
          : 'Unable to generate summary. Check reports list for raw data.';
    } catch (e) {
      print('[AiService] Summary generation error: $e');
      return 'Unable to generate AI summary. ${reports.length} reports and ${broadcastMessages.length} messages received.';
    }
  }

  /// Strips ChatML and other model-specific stop tokens that smollm2/Whisper
  /// occasionally leak into output text instead of using them as stop signals.
  ///
  /// Tokens cleaned:
  ///   <|im_end|>    — ChatML end-of-turn (smollm2, Qwen, etc.)
  ///   <|im_start|>  — ChatML start-of-turn
  ///   <|endoftext|> — GPT-style EOS
  ///   </s>          — LLaMA/Mistral EOS
  ///   <s>           — LLaMA/Mistral BOS
  static String _stripSpecialTokens(String text) {
    return text
        .replaceAll('<|im_end|>', '')
        .replaceAll('<|im_start|>', '')
        .replaceAll('<|endoftext|>', '')
        .replaceAll('</s>', '')
        .replaceAll('<s>', '')
        .trim();
  }

  /// Sanitizes model output so only user-facing guidance is displayed.
  /// Removes leaked reasoning tags/code fences and drops raw machine payloads.
  String _sanitizeAssistantOutput(
    String raw, {
    required String fallback,
  }) {
    var cleaned = _stripSpecialTokens(raw);

    // Remove hidden-reasoning blocks commonly leaked by small local models.
    cleaned = cleaned.replaceAll(
      RegExp(r'<think>[\s\S]*?<\/think>', caseSensitive: false),
      '',
    );
    cleaned = cleaned.replaceAll(
      RegExp(r'<analysis>[\s\S]*?<\/analysis>', caseSensitive: false),
      '',
    );

    // Remove markdown code-fence wrappers.
    cleaned = cleaned.replaceAll(
      RegExp(r'^\s*```[a-zA-Z0-9_-]*\s*', multiLine: true),
      '',
    );
    cleaned = cleaned.replaceAll('```', '');

    // Remove markdown formatting - be specific to avoid breaking normal text
    // Bold: **text** or __text__
    cleaned = cleaned.replaceAll(RegExp(r'\*\*(.+?)\*\*'), r'$1');
    cleaned = cleaned.replaceAll(RegExp(r'__(.+?)__'), r'$1');
    // Italic: *text* or _text_ (but be careful with underscores in words)
    cleaned = cleaned.replaceAll(RegExp(r'\*([^\*]+?)\*'), r'$1');
    // Strikethrough: ~~text~~
    cleaned = cleaned.replaceAll(RegExp(r'~~(.+?)~~'), r'$1');

    // Remove leaked role prefixes.
    cleaned = cleaned.replaceAll(
      RegExp(r'^\s*(assistant|system|user)\s*:\s*',
          caseSensitive: false, multiLine: true),
      '',
    );

    // Remove residual lone reasoning tags.
    cleaned = cleaned.replaceAll(
      RegExp(r'</?(think|analysis)>', caseSensitive: false),
      '',
    );

    // Clean up whitespace
    cleaned = cleaned.replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();

    // Only return fallback if truly empty or pure JSON
    if (cleaned.isEmpty) {
      return fallback;
    }

    // If model returned JSON payload, try to extract user-facing text field.
    if (_looksLikeJsonPayload(cleaned)) {
      final extracted = _extractTextFromJsonPayload(cleaned);
      if (extracted != null && extracted.trim().isNotEmpty) {
        cleaned = extracted.trim();
      } else {
        return fallback;
      }
    }

    return cleaned;
  }

  static bool _looksLikeJsonPayload(String text) {
    final t = text.trim();
    return (t.startsWith('{') && t.endsWith('}')) ||
        (t.startsWith('[') && t.endsWith(']'));
  }

  static String? _extractTextFromJsonPayload(String text) {
    try {
      final decoded = jsonDecode(text);
      if (decoded is Map<String, dynamic>) {
        for (final key in const ['text', 'response', 'message', 'answer']) {
          final value = decoded[key];
          if (value is String && value.trim().isNotEmpty) return value;
        }
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  void dispose() {
    _lm?.unload();
    _stt?.unload();
    _rag?.close();
    _initController.close();
  }
}
