import 'dart:async';

import 'package:cactus/cactus.dart';

import '../../core/constants.dart';
import '../../models/chat_message.dart' as app;
import '../../models/emergency_report.dart';
import 'knowledge_loader.dart';
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

class AiService {
  CactusLM? _lm;
  CactusSTT? _stt;
  CactusRAG? _rag;
  bool _lmReady = false;
  bool _sttReady = false;

  bool get isReady => _lmReady;
  bool get isSttReady => _sttReady;

  final _initController = StreamController<String>.broadcast();
  Stream<String> get initProgress => _initController.stream;

  Future<void> initialize() async {
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
    await _lm!.initializeModel(
      params: CactusInitParams(model: AiConfig.modelSlug),
    );
    _lmReady = true;

    // Load RAG knowledge base
    _initController.add('Loading knowledge base...');
    await KnowledgeLoader.loadIntoRag(_rag!, _lm!);

    // Download and init STT
    _initController.add('Downloading speech model...');
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

    _initController.add('Ready');
  }

  Future<String> transcribe(String audioPath) async {
    if (!_sttReady || _stt == null) {
      throw StateError('STT model not initialized');
    }

    final result = await _stt!.transcribe(
      audioFilePath: audioPath,
    );

    if (!result.success) {
      throw Exception('Transcription failed: ${result.errorMessage}');
    }

    return result.text;
  }

  Future<AiResponse> chat(String userText, {bool extractReport = false}) async {
    if (!_lmReady || _lm == null) {
      throw StateError('LLM not initialized');
    }

    // Search RAG for relevant knowledge
    String ragContext = '';
    if (_rag != null) {
      ragContext = await KnowledgeLoader.searchKnowledge(_rag!, userText);
    }

    // Build messages
    String fullSystemPrompt = systemPrompt;
    if (ragContext.isNotEmpty) {
      fullSystemPrompt += '\n\nRELEVANT VERIFIED PROCEDURES:\n$ragContext';
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
  }

  Future<String> generateAwarenessSummary(
    List<EmergencyReport> reports,
    List<String> broadcastMessages,
  ) async {
    if (!_lmReady || _lm == null) {
      return 'AI not ready. Showing raw data only.';
    }

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
  }

  void dispose() {
    _lm?.unload();
    _stt?.unload();
    _rag?.close();
    _initController.close();
  }
}
