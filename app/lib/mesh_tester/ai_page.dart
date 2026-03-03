import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'theme.dart';

class AiPage extends StatefulWidget {
  const AiPage({super.key});

  @override
  State<AiPage> createState() => _AiPageState();
}

class _AiPageState extends State<AiPage> {
  final TextEditingController _controller = TextEditingController();
  final List<String> _messages = [];
  bool _isRecording = false;

  void _sendMessage(String text) {
    if (text.trim().isEmpty) return;
    setState(() {
      _messages.add(text);
      _controller.clear();
    });
  }

  void _toggleRecording() {
    setState(() {
      _isRecording = !_isRecording;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
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
                        'Tap the mic or type a message to start.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.5),
                        ),
                      ),
                    ],
                  ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.1, end: 0),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(Spacing.md),
                  itemCount: _messages.length,
                  separatorBuilder: (_, __) => const SizedBox(height: Spacing.md),
                  itemBuilder: (context, index) {
                    return Align(
                      alignment: Alignment.centerRight,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: Spacing.md, vertical: Spacing.sm),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(16),
                            topRight: Radius.circular(16),
                            bottomLeft: Radius.circular(16),
                            bottomRight: Radius.circular(4),
                          ),
                        ),
                        child: Text(
                          _messages[index],
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.white,
                          ),
                        ),
                      ).animate().fadeIn(duration: 200.ms).slideX(begin: 0.1, end: 0),
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
                          decoration: const InputDecoration(
                            hintText: 'Type a message...',
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(vertical: 12),
                          ),
                          onSubmitted: _sendMessage,
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.send_rounded, color: theme.colorScheme.primary),
                        onPressed: () => _sendMessage(_controller.text),
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
