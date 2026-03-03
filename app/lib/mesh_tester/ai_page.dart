import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'theme.dart';

class _ChatMessage {
  String text;
  final bool isUser;
  
  _ChatMessage({required this.text, required this.isUser});
}

class AiPage extends StatefulWidget {
  const AiPage({super.key});

  @override
  State<AiPage> createState() => _AiPageState();
}

class _AiPageState extends State<AiPage> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<_ChatMessage> _messages = [];
  bool _isRecording = false;
  bool _isStreaming = false;

  void _sendMessage(String text, {bool isUser = true}) {
    if (text.trim().isEmpty) return;
    setState(() {
      _messages.add(_ChatMessage(text: text, isUser: isUser));
      if (isUser) _controller.clear();
    });
    _scrollToBottom();
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

  void _toggleRecording() {
    if (_isStreaming) return; // Prevent triggering multiple while already streaming
    
    if (_isRecording) {
      // Stopping recording triggers the mock response
      setState(() {
        _isRecording = false;
      });
      _triggerMockScenario();
    } else {
      // Start recording
      setState(() {
        _isRecording = true;
      });
    }
  }

  void _triggerMockScenario() async {
    // 1. Send user message
    _sendMessage("There's an earthquake!", isUser: true);
    
    // 2. Wait a brief moment to simulate processing
    setState(() => _isStreaming = true);
    await Future.delayed(const Duration(milliseconds: 600));

    // 3. Add an empty AI message to build upon
    setState(() {
      _messages.add(_ChatMessage(text: "", isUser: false));
    });
    _scrollToBottom();

    // 4. Stream response
    final responseWords = [
      "Stay", " calm.", " I'm", " here", " to", " help.\n\n",
      "1.", " Drop,", " Cover,", " and", " Hold", " On.\n",
      "2.", " Stay", " away", " from", " windows", " and", " heavy", " furniture.\n",
      "3.", " If", " indoors,", " stay", " there.", " Do", " not", " run", " outside.\n",
      "4.", " If", " outdoors,", " move", " to", " a", " clear", " area.\n\n",
      "I", " am", " monitoring", " the", " local", " RelayGo", " mesh", " sensor", " network", " for", " aftershock", " activity."
    ];

    for (var word in responseWords) {
      await Future.delayed(const Duration(milliseconds: 150)); // typing speed
      if (!mounted) return;
      
      setState(() {
        _messages.last.text += word;
      });
      _scrollToBottom();
    }
    
    if (mounted) {
      setState(() => _isStreaming = false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Column(
      children: [
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
                        'Tap the mic to simulate an emergency.',
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
                    final isUser = msg.isUser;
                    
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
                          boxShadow: isUser ? [] : [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.02),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            )
                          ],
                        ),
                        child: Text(
                          msg.text,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: isUser ? Colors.white : theme.colorScheme.onSurface,
                            height: 1.4,
                          ),
                        ),
                      ).animate().fadeIn(duration: 200.ms).slideX(begin: isUser ? 0.1 : -0.1, end: 0),
                    );
                  },
                ),
        ),

        // ── Input Area ──
        Container(
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
                          enabled: !_isStreaming,
                          decoration: const InputDecoration(
                            hintText: 'Type a message...',
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(vertical: 12),
                          ),
                          onSubmitted: (val) => _sendMessage(val),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.send_rounded, color: theme.colorScheme.primary),
                        onPressed: _isStreaming ? null : () => _sendMessage(_controller.text),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: Spacing.sm),
              GestureDetector(
                onTap: _toggleRecording,
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isRecording ? Colors.red.shade500 : theme.colorScheme.primary,
                    boxShadow: [
                      BoxShadow(
                        color: (_isRecording ? Colors.red.shade500 : theme.colorScheme.primary).withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    _isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                    color: Colors.white,
                  ),
                ).animate(target: _isRecording ? 1 : 0).scale(begin: const Offset(1,1), end: const Offset(1.1, 1.1), duration: 200.ms),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
