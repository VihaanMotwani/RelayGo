import 'dart:async';
import 'package:flutter_gemma/flutter_gemma.dart';

import '../services/ai/prompts.dart';

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
      )
          .fromNetwork(_modelUrl)
          .withProgress((progress) {
            _downloadProgress = progress / 100.0;
            _statusController.add(_status);
          })
          .install();

      _setStatus(GemmaStatus.initializing);

      _model = await FlutterGemma.getActiveModel(
        maxTokens: 1280,
        preferredBackend: PreferredBackend.gpu,
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

    _chat = await _model!.createChat(
      temperature: 0.3,
      topK: 1,
    );

    // Prime with system instruction on first message
    await _chat!.addQueryChunk(Message.text(
      text: 'You are an emergency response AI assistant. '
          'Always respond in English. Be concise and helpful. '
          'Provide clear, actionable guidance for emergencies.',
      isUser: true,
    ));

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

      await chat.addQueryChunk(Message.text(
        text: userText,
        isUser: true,
      ));

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

  void _setStatus(GemmaStatus s) {
    _status = s;
    _statusController.add(s);
  }

  Future<void> dispose() async {
    await _model?.close();
    await _statusController.close();
  }
}
