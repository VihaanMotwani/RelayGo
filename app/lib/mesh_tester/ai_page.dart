import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'gemma_service.dart';
import 'theme.dart';

/// Chat message model for the AI page.
class _ChatMsg {
  String text;
  final bool isUser;

  _ChatMsg({required this.text, required this.isUser});
}

/// AI chat page backed by on-device LLM via flutter_gemma.
class AiPage extends StatefulWidget {
  final GemmaService gemma;

  const AiPage({super.key, required this.gemma});

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

    _controller.clear();
    setState(() {
      _messages.add(_ChatMsg(text: trimmed, isUser: true));
      _isStreaming = true;
    });
    _scrollToBottom();

    // Add empty assistant bubble
    setState(() {
      _messages.add(_ChatMsg(text: '', isUser: false));
    });
    _scrollToBottom();

    // Stream tokens from LLM
    await for (final token in widget.gemma.streamChat(trimmed)) {
      if (!mounted) return;
      setState(() {
        _messages.last.text += token;
      });
      _scrollToBottom();
    }

    if (mounted) {
      setState(() => _isStreaming = false);
    }
  }

  void _toggleRecording() {
    if (_isStreaming) return;
    setState(() => _isRecording = !_isRecording);
    // STT will be wired here later
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
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(Spacing.xl),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withOpacity(0.05),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.smart_toy_rounded,
                          size: 64,
                          color: theme.colorScheme.primary.withOpacity(0.5),
                        ),
                      ),
                      const SizedBox(height: Spacing.lg),
                      Text(
                        'RelayGo AI Assistant',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface.withOpacity(0.8),
                        ),
                      ),
                      const SizedBox(height: Spacing.sm),
                      Text(
                        widget.gemma.status == GemmaStatus.ready
                            ? 'Type a message to get emergency guidance.'
                            : 'Waiting for model to load…',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.5),
                        ),
                      ),
                    ],
                  ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.1, end: 0),
                )
              : ListView.separated(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(Spacing.md),
                  itemCount: _messages.length,
                  separatorBuilder: (_, __) => const SizedBox(height: Spacing.md),
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
        label = 'AI Error: ${errText.length > 80 ? '${errText.substring(0, 80)}…' : errText}';
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
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        padding: const EdgeInsets.symmetric(horizontal: Spacing.md, vertical: Spacing.sm),
        decoration: BoxDecoration(
          color: isUser ? theme.colorScheme.primary : theme.colorScheme.surface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
          border: isUser ? null : Border.all(color: Colors.grey.shade200),
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
                  color: isUser ? Colors.white : theme.colorScheme.onSurface,
                  height: 1.4,
                ),
              ),
      ).animate().fadeIn(duration: 200.ms).slideX(begin: isUser ? 0.1 : -0.1, end: 0),
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
      padding: const EdgeInsets.fromLTRB(Spacing.md, Spacing.sm, Spacing.md, Spacing.md),
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
      child: Row(
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
                            ? 'Describe your emergency…'
                            : 'Waiting for AI model…',
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onSubmitted: (val) => _sendMessage(val),
                    ),
                  ),
                  IconButton(
                    icon: _isStreaming
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: theme.colorScheme.primary,
                            ),
                          )
                        : Icon(Icons.send_rounded, color: theme.colorScheme.primary),
                    onPressed: isReady && !_isStreaming
                        ? () => _sendMessage(_controller.text)
                        : null,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: Spacing.sm),
          GestureDetector(
            onTap: isReady ? _toggleRecording : null,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isRecording ? Colors.red.shade500 : theme.colorScheme.primary,
                boxShadow: [
                  BoxShadow(
                    color: (_isRecording ? Colors.red.shade500 : theme.colorScheme.primary)
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
            ).animate(target: _isRecording ? 1 : 0).scale(
                  begin: const Offset(1, 1),
                  end: const Offset(1.1, 1.1),
                  duration: 200.ms,
                ),
          ),
        ],
      ),
    );
  }
}
