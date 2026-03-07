import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Manages STT (speech_to_text) and TTS (flutter_tts) for the mesh tester.
///
/// GemmaService stays text-only. This service owns all audio I/O.
/// STT and TTS are serialized: TTS is silenced before STT starts,
/// and TTS will not speak while STT is active.
class VoiceService {
  final SpeechToText _stt = SpeechToText();
  final FlutterTts _tts = FlutterTts();

  bool _sttReady = false;
  bool _ttsReady = false;
  bool _isListening = false;
  bool _isSpeaking = false;
  bool _isPriming = false; // true while dummy prime listen is running
  String? _lastRecognizedText;
  String? _lastError;

  /// Called once when STT stops for any reason (silence timeout, error, or
  /// natural end of speech). Cleared before manual [stopListening] to avoid
  /// double-fire.
  VoidCallback? _onStopped;

  bool get isListening => _isListening;
  bool get isSpeaking => _isSpeaking;
  bool get isReady => _sttReady && _ttsReady;
  String? get lastRecognizedText => _lastRecognizedText;
  String? get lastError => _lastError;

  // ── Initialization ────────────────────────────────────────────────

  /// Initialize TTS immediately and warm up STT in the background after a
  /// short delay. The delay avoids iOS firing spurious "listening" status
  /// events before the app has settled, while still ensuring the speech
  /// recognizer is ready before the user taps the mic.
  Future<void> initialize() async {
    await _initTts();
    // Warm up STT 3 s after app start so the first mic tap responds instantly.
    Future.delayed(const Duration(seconds: 3), _initStt);
  }

  Future<void> _initTts() async {
    try {
      await _tts.setLanguage('en-US');
      await _tts.setSpeechRate(0.56);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);

      // iOS: share the AVAudioSession so TTS can reclaim the output route
      // after STT releases it. Without this, TTS silently does nothing after
      // the first STT session completes.
      // Do NOT include mixWithOthers — it keeps the session in a shared state
      // that reduces microphone gain when STT takes over.
      if (Platform.isIOS) {
        await _tts.setSharedInstance(true);
        await _tts.setIosAudioCategory(
          IosTextToSpeechAudioCategory.playback,
          [
            IosTextToSpeechAudioCategoryOptions.allowBluetooth,
            IosTextToSpeechAudioCategoryOptions.allowBluetoothA2DP,
          ],
          IosTextToSpeechAudioMode.defaultMode,
        );
      }

      _tts.setCompletionHandler(() {
        _isSpeaking = false;
      });
      _tts.setErrorHandler((msg) {
        _isSpeaking = false;
        _lastError = 'TTS: $msg';
        debugPrint('[VoiceService] TTS error: $msg');
      });

      _ttsReady = true;
      debugPrint('[VoiceService] TTS ready');
    } catch (e) {
      _lastError = 'TTS init failed: $e';
      debugPrint('[VoiceService] TTS init failed: $e');
    }
  }

  Future<void> _initStt() async {
    try {
      _sttReady = await _stt.initialize(
        onError: (SpeechRecognitionError error) {
          if (_isPriming) return; // ignore callbacks from the dummy prime session
          _lastError = error.errorMsg;
          _isListening = false;
          debugPrint('[VoiceService] STT error: ${error.errorMsg}');
          _fireOnStopped();
        },
        onStatus: (String status) {
          debugPrint('[VoiceService] STT status: $status');
          if (_isPriming) return; // ignore callbacks from the dummy prime session
          if (status == 'done' || status == 'notListening') {
            _isListening = false;
            _fireOnStopped();
          }
        },
      );
      debugPrint('[VoiceService] STT ready: $_sttReady');

      // iOS: SFSpeechRecognizer silently fails on the very first listen call
      // because its internal audio pipeline hasn't been set up yet.
      // A brief dummy listen primes it so the first real recording works.
      if (Platform.isIOS && _sttReady) {
        await _primeStt();
      }
    } catch (e) {
      _lastError = 'STT init failed: $e';
      debugPrint('[VoiceService] STT init failed: $e');
    }
  }

  Future<void> _primeStt() async {
    _isPriming = true;
    try {
      debugPrint('[VoiceService] Priming STT...');
      await _stt.listen(
        onResult: (_) {},
        listenFor: const Duration(milliseconds: 200),
        pauseFor: const Duration(milliseconds: 200),
        listenOptions: SpeechListenOptions(
          partialResults: false,
          cancelOnError: true,
        ),
      );
      await Future.delayed(const Duration(milliseconds: 500));
      await _stt.stop();
      // Wait long enough for all iOS status/error callbacks from the prime
      // session to fire while the guard is still active. Without this, they
      // bleed into the first real listen and trigger a premature onStopped.
      await Future.delayed(const Duration(milliseconds: 1000));
      debugPrint('[VoiceService] STT primed');
    } catch (e) {
      debugPrint('[VoiceService] STT prime failed (non-fatal): $e');
    } finally {
      _isPriming = false;
    }
  }

  void _fireOnStopped() {
    final cb = _onStopped;
    _onStopped = null; // fire at most once per listen session
    cb?.call();
  }

  /// Re-attempt STT initialization (e.g. after permission denial then grant).
  Future<bool> ensureSpeechReady() async {
    if (_sttReady) return true;
    await _initStt();
    return _sttReady;
  }

  // ── STT ───────────────────────────────────────────────────────────

  /// Start listening.
  ///
  /// [onResult] — called with partial and final transcriptions.
  /// [onStopped] — called once when STT stops for any reason (silence
  ///   timeout, error, natural end). NOT called when [stopListening] is
  ///   invoked manually.
  Future<bool> startListening({
    required void Function(String text, bool isFinal) onResult,
    VoidCallback? onStopped,
  }) async {
    if (!_sttReady) {
      if (!await ensureSpeechReady()) return false;
    }

    // Stop TTS before mic opens to avoid the microphone picking up speaker
    // output. iOS needs time to: (1) drain the TTS audio buffer, (2) release
    // the AVAudioSession output route, and (3) activate the input route.
    // 700 ms is enough for normal speech rate; lower values cause the mic
    // to hear the tail of the TTS utterance and transcribe it as user speech.
    if (_isSpeaking) {
      await stopSpeaking();
      await Future.delayed(const Duration(milliseconds: 700));
    } else {
      // Even when not speaking, give the audio session a moment to settle.
      await Future.delayed(const Duration(milliseconds: 150));
    }
    if (_isListening) await stopListening();

    _lastError = null;
    _lastRecognizedText = null;
    _onStopped = onStopped;

    try {
      _isListening = true;
      await _stt.listen(
        onResult: (SpeechRecognitionResult result) {
          _lastRecognizedText = result.recognizedWords;
          onResult(result.recognizedWords, result.finalResult);
          if (result.finalResult) {
            _isListening = false;
          }
        },
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
        listenOptions: SpeechListenOptions(
          partialResults: true,
          cancelOnError: true,
        ),
      );
      return true;
    } catch (e) {
      _isListening = false;
      _lastError = 'startListening failed: $e';
      debugPrint('[VoiceService] startListening failed: $e');
      _fireOnStopped();
      return false;
    }
  }

  /// Stop listening manually. Returns the last recognized text.
  /// Clears the [onStopped] callback so it is NOT called after manual stop
  /// (the caller handles the result directly).
  Future<String?> stopListening() async {
    _onStopped = null; // prevent double-fire when we stop manually
    if (!_isListening) return _lastRecognizedText;
    try {
      await _stt.stop();
      // iOS processes audio asynchronously after stop() — the final onResult
      // callback (which sets _isListening=false and populates _lastRecognizedText)
      // can arrive up to ~800 ms later. Poll until it fires or we time out.
      for (int i = 0; i < 16; i++) {
        await Future.delayed(const Duration(milliseconds: 50));
        if (!_isListening) break;
      }
    } catch (e) {
      debugPrint('[VoiceService] stopListening error: $e');
    }
    _isListening = false;
    return _lastRecognizedText;
  }

  // ── TTS ───────────────────────────────────────────────────────────

  /// Speak a text chunk. Enqueued immediately; does not block the caller.
  /// The TTS engine queues chunks internally. Does nothing if STT is active.
  Future<void> speakChunk(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || !_ttsReady || _isListening) return;
    _isSpeaking = true;
    // Intentionally not awaited — TTS runs concurrently with token streaming.
    _tts.speak(trimmed);
  }

  /// Stop speaking and clear any queued chunks.
  Future<void> stopSpeaking() async {
    if (!_ttsReady) return;
    try {
      await _tts.stop();
    } catch (e) {
      debugPrint('[VoiceService] stopSpeaking error: $e');
    }
    _isSpeaking = false;
  }

  // ── Lifecycle ─────────────────────────────────────────────────────

  Future<void> dispose() async {
    _onStopped = null;
    await stopListening();
    await stopSpeaking();
  }
}
