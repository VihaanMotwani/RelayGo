import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_gemma/flutter_gemma.dart';

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

  // ── Serialization & Stop ─────────────────────────────────────────

  /// True while any inference (chat or extraction) is running.
  bool _isBusy = false;
  bool get isBusy => _isBusy;

  /// Set to true to request cancellation of the current inference.
  bool _stopRequested = false;

  /// Request that the current streaming inference stop as soon as possible.
  void stopInference() {
    _stopRequested = true;
  }

  // ── Token limits ─────────────────────────────────────────────────

  /// Max tokens for the main chat response. The 0.5B model tends to
  /// repeat itself; 500 tokens is ~375 words — more than enough for
  /// emergency guidance. Anything beyond that is a repetition loop.
  static const _maxChatTokens = 500;

  /// Max tokens for extraction output. Well-formed JSON is ~50-80 tokens.
  static const _maxExtractionTokens = 200;

  /// Initialize: download model (if needed) and load it.
  Future<void> initialize() async {
    try {
      _setStatus(GemmaStatus.downloading);

      await FlutterGemma.installModel(
        modelType: ModelType.qwen,
      ).fromNetwork(_modelUrl).withProgress((progress) {
        _downloadProgress = progress / 100.0;
        _statusController.add(_status);
      }).install();

      _setStatus(GemmaStatus.initializing);

      _model = await FlutterGemma.getActiveModel(
        maxTokens: 1280,
        preferredBackend: PreferredBackend.cpu,
      );

      // Warm up the chat session while still in initializing state,
      // so the first user message responds immediately.
      await _getOrCreateChat();

      _setStatus(GemmaStatus.ready);
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

    await _chat!.addQueryChunk(
      Message.text(
        text:
            'You are a calm, caring emergency response assistant. '
            'Speak naturally and conversationally, like a knowledgeable friend helping in a crisis. '
            'Be warm, reassuring, and clear. Give practical step-by-step guidance when needed. '
            'Always respond in English. Keep responses focused and under 120 words.',
        isUser: true,
      ),
    );

    await for (final _ in _chat!.generateChatResponseAsync()) {}

    _chatInitialized = true;
    return _chat!;
  }

  /// Stream a chat response token by token.
  ///
  /// Has a [_maxChatTokens] safety limit and repetition detection
  /// to handle the 0.5B model's tendency to loop.
  Stream<String> streamChat(String userText) async* {
    if (_model == null || _status != GemmaStatus.ready) {
      yield 'AI model not ready. Please wait for initialization.';
      return;
    }
    if (_isBusy) {
      yield 'Model is busy. Please wait for the current response to finish.';
      return;
    }

    _isBusy = true;
    _stopRequested = false;

    try {
      final chat = await _getOrCreateChat();

      await chat.addQueryChunk(Message.text(text: userText, isUser: true));

      var tokenCount = 0;
      final fullResponse = StringBuffer();
      var brokeEarly = false;

      await for (final response in chat.generateChatResponseAsync()) {
        if (_stopRequested) {
          debugPrint('[streamChat] stop requested — breaking');
          brokeEarly = true;
          break;
        }

        tokenCount++;
        if (tokenCount > _maxChatTokens) {
          debugPrint('[streamChat] hit $tokenCount tokens — breaking');
          brokeEarly = true;
          break;
        }

        if (response is TextResponse) {
          fullResponse.write(response.token);
          yield response.token;

          // Repetition detection: if the response so far is > 200 chars,
          // check if the last 40 chars have appeared before in the output.
          // This catches the "If you're in a car... If you're in a building..."
          // loop pattern.
          if (fullResponse.length > 200) {
            final text = fullResponse.toString();
            final tail = text.substring(text.length - 40);
            final beforeTail = text.substring(0, text.length - 40);
            if (beforeTail.contains(tail)) {
              debugPrint('[streamChat] repetition detected — breaking');
              brokeEarly = true;
              break;
            }
          }
        }
      }

      // If we broke out before the native engine called PredictDone,
      // reset the session AND give the native engine time to settle
      // before allowing a new inference. Without the delay the next
      // addQueryChunk call races against the pending PredictDone.
      if (brokeEarly) {
        _chat = null;
        _chatInitialized = false;
        await Future.delayed(const Duration(milliseconds: 600));
      }
    } catch (e) {
      // Session may be corrupt after an error — reset it.
      _chat = null;
      _chatInitialized = false;
      await Future.delayed(const Duration(milliseconds: 600));
      yield '\n[Error: $e]';
    } finally {
      _isBusy = false;
      _stopRequested = false;
    }
  }

  // ── Per-turn prompt streaming ──────────────────────────────────────

  /// Stream a response for a pre-assembled prompt using a **fresh** chat
  /// session. Unlike [streamChat], this never touches the persistent chat
  /// history, making it safe for per-turn RAG calls from ChatService.
  Stream<String> streamPrompt(String fullPrompt) async* {
    if (_model == null || _status != GemmaStatus.ready) {
      yield 'AI model not ready. Please wait for initialization.';
      return;
    }
    if (_isBusy) {
      yield 'Model is busy. Please wait for the current response to finish.';
      return;
    }

    _isBusy = true;
    _stopRequested = false;

    try {
      final chat = await _model!.createChat(temperature: 0.3, topK: 1);
      await chat.addQueryChunk(Message.text(text: fullPrompt, isUser: true));

      var tokenCount = 0;
      final fullResponse = StringBuffer();
      var brokeEarly = false;

      await for (final response in chat.generateChatResponseAsync()) {
        if (_stopRequested) {
          brokeEarly = true;
          break;
        }
        tokenCount++;
        if (tokenCount > _maxChatTokens) {
          brokeEarly = true;
          break;
        }
        if (response is TextResponse) {
          fullResponse.write(response.token);
          yield response.token;

          if (fullResponse.length > 200) {
            final text = fullResponse.toString();
            final tail = text.substring(text.length - 40);
            final beforeTail = text.substring(0, text.length - 40);
            if (beforeTail.contains(tail)) {
              brokeEarly = true;
              break;
            }
          }
        }
      }

      if (brokeEarly) {
        await Future.delayed(const Duration(milliseconds: 600));
      }
    } catch (e) {
      await Future.delayed(const Duration(milliseconds: 600));
      yield '[Error: $e]';
    } finally {
      _isBusy = false;
      _stopRequested = false;
    }
  }

  // ── Description Shortener ──────────────────────────────────────────

  /// Shorten a description to fit the 100-character BLE wire budget.
  ///
  /// Uses a one-shot LLM session to rephrase without losing critical details.
  /// Returns the shortened text, or `null` on failure.
  Future<String?> shortenDescription(String longDesc) async {
    if (_model == null || _status != GemmaStatus.ready) return null;

    // Wait briefly if busy
    if (_isBusy) {
      debugPrint('[shortenDesc] model busy — waiting up to 500ms');
      for (int i = 0; i < 10; i++) {
        await Future.delayed(const Duration(milliseconds: 50));
        if (!_isBusy) break;
      }
      if (_isBusy) {
        debugPrint('[shortenDesc] still busy after 500ms — skipping');
        return null;
      }
    }

    _isBusy = true;
    _stopRequested = false;
    debugPrint('[shortenDesc] starting (input ${longDesc.length} chars)');

    try {
      final chat = await _model!.createChat(temperature: 0.2, topK: 1);

      final prompt =
          'Shorten this emergency description to under 100 characters. '
          'Keep all critical details. Return ONLY the shortened text, '
          'nothing else.\n\n$longDesc';

      await chat.addQueryChunk(Message.text(text: prompt, isUser: true));

      final buffer = StringBuffer();
      var tokenCount = 0;
      await for (final response in chat.generateChatResponseAsync()) {
        if (_stopRequested) break;
        tokenCount++;
        if (tokenCount > _maxExtractionTokens) break;
        if (response is TextResponse) {
          buffer.write(response.token);
        }
      }

      final result = buffer.toString().trim();
      debugPrint(
        '[shortenDesc] output ($tokenCount tokens, ${result.length} chars): $result',
      );

      // Only accept if it's actually shorter and non-empty
      if (result.isNotEmpty && result.length <= 100) {
        return result;
      }
      // If still > 100, hard truncate
      if (result.isNotEmpty) {
        return result.substring(0, 100);
      }
      return null;
    } catch (e) {
      debugPrint('[shortenDesc] error: $e');
      return null;
    } finally {
      _isBusy = false;
      _stopRequested = false;
    }
  }

  void _setStatus(GemmaStatus s) {
    _status = s;
    _statusController.add(s);
  }

  Future<void> dispose() async {
    _stopRequested = true;
    await _model?.close();
    await _statusController.close();
  }
}
