import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'gemma_service.dart';
import 'speech_chunker.dart';
import 'theme.dart';
import 'voice_service.dart';

/// Chat message model for the AI page.
class _ChatMsg {
  String text;
  final bool isUser;

  _ChatMsg({required this.text, required this.isUser});
}

/// Pure AI chat page backed by on-device LLM via flutter_gemma.
///
/// No extraction, no packet creation — just emergency guidance chat.
class AiPage extends StatefulWidget {
  final GemmaService gemma;
  final VoiceService voice;

  const AiPage({super.key, required this.gemma, required this.voice});

  @override
  State<AiPage> createState() => _AiPageState();
}

class _AiPageState extends State<AiPage> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<_ChatMsg> _messages = [];

  bool _isStreaming = false;
  bool _isRecording = false;
  StreamSubscription? _statusSub;

  final SpeechChunker _chunker = SpeechChunker();
  String? _voiceStatusText;
  String? _voiceErrorText;
  bool _voiceRepliesEnabled = true;

  @override
  void initState() {
    super.initState();
    _statusSub = widget.gemma.onStatusChanged.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _statusSub?.cancel();
    widget.voice.stopListening();
    widget.voice.stopSpeaking();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _isStreaming) return;

    // If the LLM was interrupted, it needs a moment to call PredictDone
    // before a new inference can start. Poll for up to 2 s.
    if (widget.gemma.isBusy) {
      for (int i = 0; i < 20; i++) {
        await Future.delayed(const Duration(milliseconds: 100));
        if (!widget.gemma.isBusy) break;
      }
      if (widget.gemma.isBusy) return; // still busy — give up
    }

    // Stop any ongoing TTS and reset chunker for the new response.
    await widget.voice.stopSpeaking();
    _chunker.reset();

    _controller.clear();
    setState(() {
      _messages.add(_ChatMsg(text: trimmed, isUser: true));
      _isStreaming = true;
      _voiceErrorText = null;
    });
    _scrollToBottom();

    // Add empty assistant bubble
    setState(() {
      _messages.add(_ChatMsg(text: '', isUser: false));
    });
    _scrollToBottom();

    // Stream tokens from LLM; feed each token to the TTS chunker.
    await for (final token in widget.gemma.streamChat(trimmed)) {
      if (!mounted) return;
      setState(() {
        _messages.last.text += token;
      });
      _scrollToBottom();

      if (_voiceRepliesEnabled) {
        for (final chunk in _chunker.push(token)) {
          await widget.voice.speakChunk(chunk);
        }
      }
    }

    // Flush remaining buffered text when the stream ends.
    if (_voiceRepliesEnabled && mounted) {
      final tail = _chunker.flush();
      if (tail != null) await widget.voice.speakChunk(tail);
    }

    if (!mounted) return;
    setState(() => _isStreaming = false);
  }

  Future<void> _toggleRecording() async {
    // ── Already listening: user tapped to stop ──────────────────────
    if (_isRecording) {
      // Clear _isRecording BEFORE awaiting stopListening so that any onResult
      // callback firing during the poll (see VoiceService) is ignored and
      // doesn't trigger a double _sendMessage call.
      setState(() {
        _isRecording = false;
        _voiceStatusText = null;
      });
      final finalText = await widget.voice.stopListening();
      if (finalText != null && finalText.trim().isNotEmpty) {
        await _sendMessage(finalText);
      } else {
        setState(() => _voiceErrorText = 'No speech detected');
      }
      return;
    }

    // ── Not listening: start ────────────────────────────────────────
    // If LLM is still streaming, interrupt it first.
    if (_isStreaming) {
      widget.gemma.stopInference();
      _chunker.reset();
      setState(() => _isStreaming = false);
    }
    if (widget.voice.isSpeaking) await widget.voice.stopSpeaking();

    setState(() {
      _voiceStatusText = 'Initializing…';
      _voiceErrorText = null;
    });

    final ready = await widget.voice.ensureSpeechReady();
    if (!ready) {
      setState(() {
        _voiceStatusText = null;
        _voiceErrorText =
            widget.voice.lastError ?? 'Speech recognition unavailable';
      });
      return;
    }

    setState(() {
      _isRecording = true;
      _voiceStatusText = 'Listening…';
    });

    final started = await widget.voice.startListening(
      onResult: (text, isFinal) {
        if (!mounted) return;
        // Only process results if we explicitly started recording.
        // Guards against spurious OS-level STT callbacks.
        if (!_isRecording) return;
        if (isFinal) {
          setState(() {
            _isRecording = false;
            _voiceStatusText = null;
          });
          if (text.trim().isNotEmpty) {
            _sendMessage(text);
          }
        }
      },
      // Called when STT auto-stops (silence timeout, error).
      // Only acts if onResult(isFinal=true) hasn't already handled the result
      // (i.e. _isRecording is still true — onResult sets it to false).
      onStopped: () {
        if (!mounted) return;
        if (!_isRecording) return; // onResult already handled the final result
        final recognized = widget.voice.lastRecognizedText?.trim() ?? '';
        setState(() {
          _isRecording = false;
          _voiceStatusText = null;
          if (recognized.isEmpty) {
            _voiceErrorText =
                widget.voice.lastError == null ||
                        widget.voice.lastError!.contains('No speech')
                    ? 'No speech detected'
                    : widget.voice.lastError;
          }
        });
        if (recognized.isNotEmpty) {
          _sendMessage(recognized);
        }
      },
    );

    if (!started) {
      setState(() {
        _isRecording = false;
        _voiceStatusText = null;
        _voiceErrorText =
            widget.voice.lastError ?? 'Could not start recording';
      });
    }
  }

  /// Stop LLM inference, TTS playback, and reset the speech chunker.
  void _stopGeneration() {
    widget.gemma.stopInference();
    widget.voice.stopSpeaking();
    _chunker.reset();
    setState(() => _isStreaming = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        // ── Status Banner ──
        _buildStatusBanner(theme),

        // ── Chat Messages ──
        Expanded(
          child: _messages.isEmpty
              ? Center(
                  child:
                      Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(Spacing.xl),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary.withOpacity(
                                    0.05,
                                  ),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.smart_toy_rounded,
                                  size: 64,
                                  color: theme.colorScheme.primary.withOpacity(
                                    0.5,
                                  ),
                                ),
                              ),
                              const SizedBox(height: Spacing.lg),
                              Text(
                                'RelayGo AI Assistant',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(0.8),
                                ),
                              ),
                              const SizedBox(height: Spacing.sm),
                              Text(
                                widget.gemma.status == GemmaStatus.ready
                                    ? 'Ask for emergency guidance.'
                                    : 'Waiting for model to load…',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(0.5),
                                ),
                              ),
                            ],
                          )
                          .animate()
                          .fadeIn(duration: 500.ms)
                          .slideY(begin: 0.1, end: 0),
                )
              : ListView.separated(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(Spacing.md),
                  itemCount: _messages.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: Spacing.md),
                  itemBuilder: (context, index) {
                    final msg = _messages[index];
                    return _buildBubble(theme, msg);
                  },
                ),
        ),

        // ── Input Area ──
        _buildInputBar(theme),
      ],
    );
  }

  Widget _buildStatusBanner(ThemeData theme) {
    final status = widget.gemma.status;
    if (status == GemmaStatus.ready) return const SizedBox.shrink();

    String label;
    Color color;
    bool showProgress = false;

    switch (status) {
      case GemmaStatus.idle:
        label = 'AI model not loaded';
        color = Colors.grey.shade500;
        break;
      case GemmaStatus.downloading:
        final pct = (widget.gemma.downloadProgress * 100).toStringAsFixed(0);
        label = 'Downloading Qwen 2.5 0.5B… $pct%';
        color = theme.colorScheme.primary;
        showProgress = true;
        break;
      case GemmaStatus.initializing:
        label = 'Loading model…';
        color = Colors.orange.shade500;
        showProgress = true;
        break;
      case GemmaStatus.error:
        final errText = widget.gemma.error ?? 'unknown';
        label =
            'AI Error: ${errText.length > 80 ? '${errText.substring(0, 80)}…' : errText}';
        color = Colors.red.shade500;
        break;
      case GemmaStatus.ready:
        label = '';
        color = Colors.transparent;
        break;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: Spacing.md, vertical: 10),
      color: color.withOpacity(0.08),
      child: Column(
        children: [
          Row(
            children: [
              if (showProgress)
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: color,
                  ),
                ),
              if (showProgress) const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (showProgress && status == GemmaStatus.downloading)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: widget.gemma.downloadProgress,
                  minHeight: 3,
                  backgroundColor: color.withOpacity(0.15),
                  valueColor: AlwaysStoppedAnimation(color),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBubble(ThemeData theme, _ChatMsg msg) {
    final isUser = msg.isUser;
    final isEmpty = msg.text.isEmpty;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child:
          Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.75,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: Spacing.md,
                  vertical: Spacing.sm,
                ),
                decoration: BoxDecoration(
                  color: isUser
                      ? theme.colorScheme.primary
                      : theme.colorScheme.surface,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: Radius.circular(isUser ? 16 : 4),
                    bottomRight: Radius.circular(isUser ? 4 : 16),
                  ),
                  border: isUser
                      ? null
                      : Border.all(color: Colors.grey.shade200),
                  boxShadow: isUser
                      ? []
                      : [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.02),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                ),
                child: isEmpty
                    ? _buildTypingIndicator(theme)
                    : Text(
                        msg.text,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: isUser
                              ? Colors.white
                              : theme.colorScheme.onSurface,
                          height: 1.4,
                        ),
                      ),
              )
              .animate()
              .fadeIn(duration: 200.ms)
              .slideX(begin: isUser ? 0.1 : -0.1, end: 0),
    );
  }

  Widget _buildTypingIndicator(ThemeData theme) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        return Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
            )
            .animate(onPlay: (c) => c.repeat())
            .fadeIn(delay: Duration(milliseconds: i * 200))
            .then()
            .fadeOut(delay: 400.ms);
      }),
    );
  }

  Widget _buildInputBar(ThemeData theme) {
    final isReady = widget.gemma.status == GemmaStatus.ready;

    return Container(
      padding: const EdgeInsets.fromLTRB(
        Spacing.md,
        Spacing.sm,
        Spacing.md,
        Spacing.md,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_voiceStatusText != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 6, left: 4),
              child: Text(
                _voiceStatusText!,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          if (_voiceErrorText != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 6, left: 4),
              child: Text(
                _voiceErrorText!,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: Colors.red.shade500,
                ),
              ),
            ),
          Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                children: [
                  const SizedBox(width: Spacing.md),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      textCapitalization: TextCapitalization.sentences,
                      minLines: 1,
                      maxLines: 4,
                      enabled: isReady && !_isStreaming,
                      decoration: InputDecoration(
                        hintText: isReady
                            ? 'Ask for emergency guidance…'
                            : 'Waiting for AI model…',
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 12,
                        ),
                      ),
                      onSubmitted: (val) => _sendMessage(val),
                    ),
                  ),
                  IconButton(
                    icon: _isStreaming
                        ? Icon(
                            Icons.stop_rounded,
                            color: Colors.red.shade500,
                            size: 22,
                          )
                        : Icon(
                            Icons.send_rounded,
                            color: theme.colorScheme.primary,
                          ),
                    onPressed: _isStreaming
                        ? _stopGeneration
                        : isReady
                        ? () => _sendMessage(_controller.text)
                        : null,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: Spacing.sm),
          GestureDetector(
            onTap: (isReady || _isStreaming) ? () { _toggleRecording(); } : null,
            child:
                Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isRecording
                            ? Colors.red.shade500
                            : theme.colorScheme.primary,
                        boxShadow: [
                          BoxShadow(
                            color:
                                (_isRecording
                                        ? Colors.red.shade500
                                        : theme.colorScheme.primary)
                                    .withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(
                        _isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                        color: Colors.white,
                      ),
                    )
                    .animate(target: _isRecording ? 1 : 0)
                    .scale(
                      begin: const Offset(1, 1),
                      end: const Offset(1.1, 1.1),
                      duration: 200.ms,
                    ),
          ),
        ],
      ),        // end Row
        ],
      ),        // end Column
    );
  }
}
