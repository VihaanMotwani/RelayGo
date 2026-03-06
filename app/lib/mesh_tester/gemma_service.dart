import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_gemma/flutter_gemma.dart';

import '../models/extraction_result.dart';

/// Status of the Gemma model lifecycle.
enum GemmaStatus { idle, downloading, initializing, ready, error }

/// Thin wrapper around flutter_gemma for the mesh tester.
class GemmaService {
  static const _modelUrl =
      'https://huggingface.co/litert-community/Qwen2.5-0.5B-Instruct/resolve/main/Qwen2.5-0.5B-Instruct_multi-prefill-seq_q8_ekv1280.task';

  GemmaStatus _status = GemmaStatus.idle;
  GemmaStatus get status => _status;

  double _downloadProgress = 0;
  double get downloadProgress => _downloadProgress;

  String? _error;
  String? get error => _error;

  InferenceModel? _model;

  final _statusController = StreamController<GemmaStatus>.broadcast();
  Stream<GemmaStatus> get onStatusChanged => _statusController.stream;

  /// Initialize: download model (if needed) and load it.
  Future<void> initialize() async {
    try {
      _setStatus(GemmaStatus.downloading);

      // Always install — ensures correct model is active
      // (clears any stale model specs from previous failed installs)
      await FlutterGemma.installModel(
        modelType: ModelType.qwen,
      ).fromNetwork(_modelUrl).withProgress((progress) {
        _downloadProgress = progress / 100.0;
        _statusController.add(_status);
      }).install();

      _setStatus(GemmaStatus.initializing);

      // CPU backend works reliably on both iOS and Android.
      // GPU path initialises successfully but crashes at inference time on
      // Android (DetokenizerCalculator gets token id=-1 from the GPU→CPU
      // op fallback), so try-catch at init cannot intercept it.
      _model = await FlutterGemma.getActiveModel(
        maxTokens: 1280,
        preferredBackend: PreferredBackend.cpu,
      );

      _setStatus(GemmaStatus.ready);

      // Warm up: create chat session and prime system prompt in background
      // so the first user message doesn't have to wait
      _getOrCreateChat();
    } catch (e) {
      _error = e.toString();
      _setStatus(GemmaStatus.error);
    }
  }

  InferenceChat? _chat;
  bool _chatInitialized = false;

  /// Ensure the chat session exists (created once, reused across turns).
  Future<InferenceChat> _getOrCreateChat() async {
    if (_chat != null && _chatInitialized) return _chat!;

    _chat = await _model!.createChat(temperature: 0.3, topK: 1);

    // Prime with system instruction on first message
    await _chat!.addQueryChunk(
      Message.text(
        text:
            'You are an emergency response AI assistant. '
            'Always respond in English. Be concise and helpful. '
            'Provide clear, actionable guidance for emergencies.',
        isUser: true,
      ),
    );

    // Generate and discard the system-level reply so the model
    // "acknowledges" the instruction before real user input
    await for (final _ in _chat!.generateChatResponseAsync()) {}

    _chatInitialized = true;
    return _chat!;
  }

  /// Stream a chat response token by token.
  Stream<String> streamChat(String userText) async* {
    if (_model == null || _status != GemmaStatus.ready) {
      yield 'AI model not ready. Please wait for initialization.';
      return;
    }

    try {
      final chat = await _getOrCreateChat();

      await chat.addQueryChunk(Message.text(text: userText, isUser: true));

      // Stream the response
      final responseStream = chat.generateChatResponseAsync();

      await for (final response in responseStream) {
        if (response is TextResponse) {
          yield response.token;
        }
      }
    } catch (e) {
      yield '\n[Error: $e]';
    }
  }

  // ── Extraction (Turn 2 — Silent) ──────────────────────────────────

  static const _extractionPrompt =
      '''Extract emergency data from this conversation as JSON only. No other text.

Schema (desc max 100 chars):
{"type":"...","urg":N,"haz":[],"desc":"...","c":{"t":"high|medium|low","u":"high|medium|low","d":"high|medium|low"}}

Types: fire, medical, structural, flood, hazmat, other
Urgency: 1-5 (5=life threatening)
Hazards: gas_leak,fire_spread,structural_collapse,flooding,chemical_spill,downed_power_lines,trapped_people
If not an emergency: {"type":null}
''';

  /// Run a silent second inference call to extract structured emergency data.
  ///
  /// Uses a separate chat session so we don't pollute the main conversation
  /// history with extraction prompts.
  Future<ExtractionResult?> extractEmergency(
    String userText,
    String aiResponse,
  ) async {
    if (_model == null || _status != GemmaStatus.ready) return null;

    try {
      // Create a one-shot session for extraction
      final extractChat = await _model!.createChat(
        temperature: 0.1, // low temperature for deterministic JSON
        topK: 1,
      );

      final prompt =
          '$_extractionPrompt\n'
          'User said: $userText\n'
          'AI responded: $aiResponse\n'
          'JSON:';

      await extractChat.addQueryChunk(Message.text(text: prompt, isUser: true));

      // Collect the full response (non-streaming)
      final buffer = StringBuffer();
      await for (final response in extractChat.generateChatResponseAsync()) {
        if (response is TextResponse) {
          buffer.write(response.token);
        }
      }

      final rawOutput = buffer.toString().trim();
      debugPrint('[extractEmergency] raw output: $rawOutput');

      return ExtractionResult.tryParse(rawOutput);
    } catch (e) {
      debugPrint('[extractEmergency] error: $e');
      return null;
    }
  }

  void _setStatus(GemmaStatus s) {
    _status = s;
    _statusController.add(s);
  }

  Future<void> dispose() async {
    await _model?.close();
    await _statusController.close();
  }
}
