import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../providers/chat_provider.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/recording_indicator.dart';

class ChatScreen extends StatefulWidget {
  final bool isSOS;

  const ChatScreen({super.key, this.isSOS = false});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    if (widget.isSOS) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<ChatProvider>().triggerSOS();
      });
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final chat = context.watch<ChatProvider>();

    // Auto-scroll when messages change
    _scrollToBottom();

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppTheme.emergencyRed.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(
                Icons.emergency,
                size: 18,
                color: AppTheme.emergencyRed,
              ),
            ),
            const SizedBox(width: 8),
            const Text('Emergency AI'),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: chat.messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 48,
                          color: AppTheme.textMuted.withValues(alpha: 0.3),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          widget.isSOS
                              ? 'Describe your emergency'
                              : 'Ask about emergency procedures',
                          style: TextStyle(
                            color: AppTheme.textMuted,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: chat.messages.length,
                    itemBuilder: (_, i) => ChatBubble(message: chat.messages[i]),
                  ),
          ),
          if (chat.isRecording)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: RecordingIndicator(),
            ),
          if (chat.isProcessing)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.cyan,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Processing...',
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                  ),
                ],
              ),
            ),
          _buildInputBar(chat),
        ],
      ),
    );
  }

  Widget _buildInputBar(ChatProvider chat) {
    return Container(
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border(
          top: BorderSide(color: AppTheme.cyan.withValues(alpha: 0.15)),
        ),
      ),
      child: Row(
        children: [
          // Mic button
          IconButton(
            onPressed: chat.isProcessing ? null : () => chat.toggleRecording(),
            icon: Icon(
              chat.isRecording ? Icons.stop_circle : Icons.mic,
              color: chat.isRecording ? AppTheme.emergencyRed : AppTheme.cyan,
            ),
          ),
          // Text input
          Expanded(
            child: TextField(
              controller: _textController,
              style: const TextStyle(color: AppTheme.textColor),
              decoration: InputDecoration(
                hintText: 'Describe your situation...',
                hintStyle: TextStyle(color: AppTheme.textMuted),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
              onSubmitted: (_) => _send(chat),
            ),
          ),
          // Send button
          IconButton(
            onPressed: chat.isProcessing ? null : () => _send(chat),
            icon: Icon(
              Icons.send,
              color: AppTheme.cyan,
            ),
          ),
        ],
      ),
    );
  }

  void _send(ChatProvider chat) {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    _textController.clear();
    chat.sendTextMessage(text);
  }
}
