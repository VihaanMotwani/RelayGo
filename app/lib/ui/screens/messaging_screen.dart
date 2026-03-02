import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../providers/messaging_provider.dart';
import '../widgets/message_bubble.dart';
import 'conversation_screen.dart';

class MessagingScreen extends StatefulWidget {
  const MessagingScreen({super.key});

  @override
  State<MessagingScreen> createState() => _MessagingScreenState();
}

class _MessagingScreenState extends State<MessagingScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.cyan,
          labelColor: AppTheme.cyan,
          unselectedLabelColor: AppTheme.textMuted,
          tabs: const [
            Tab(text: 'Broadcast'),
            Tab(text: 'Direct'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _BroadcastTab(),
          _DirectTab(),
        ],
      ),
    );
  }
}

class _BroadcastTab extends StatefulWidget {
  const _BroadcastTab();

  @override
  State<_BroadcastTab> createState() => _BroadcastTabState();
}

class _BroadcastTabState extends State<_BroadcastTab> {
  final _textController = TextEditingController();

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final messaging = context.watch<MessagingProvider>();
    final messages = messaging.broadcastMessages;

    return Column(
      children: [
        Expanded(
          child: messages.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.cell_tower,
                        size: 48,
                        color: AppTheme.textMuted.withValues(alpha: 0.3),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No broadcast messages yet',
                        style: TextStyle(color: AppTheme.textMuted),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Messages from the mesh network appear here',
                        style: TextStyle(
                          color: AppTheme.textMuted.withValues(alpha: 0.6),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: messages.length,
                  itemBuilder: (_, i) => MessageBubble(
                    message: messages[i],
                    isMe: false, // Broadcasts shown left-aligned
                  ),
                ),
        ),
        _buildInputBar(messaging),
      ],
    );
  }

  Widget _buildInputBar(MessagingProvider messaging) {
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
          Expanded(
            child: TextField(
              controller: _textController,
              style: const TextStyle(color: AppTheme.textColor),
              decoration: InputDecoration(
                hintText: 'Broadcast to everyone nearby...',
                hintStyle: TextStyle(color: AppTheme.textMuted),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
              onSubmitted: (_) => _send(messaging),
            ),
          ),
          IconButton(
            onPressed: () => _send(messaging),
            icon: const Icon(Icons.send, color: AppTheme.cyan),
          ),
        ],
      ),
    );
  }

  void _send(MessagingProvider messaging) {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    _textController.clear();
    messaging.sendBroadcast(text);
  }
}

class _DirectTab extends StatelessWidget {
  const _DirectTab();

  @override
  Widget build(BuildContext context) {
    final messaging = context.watch<MessagingProvider>();
    final peerIds = messaging.dmPeerIds;

    if (peerIds.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.forum_outlined,
              size: 48,
              color: AppTheme.textMuted.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 12),
            Text(
              'No direct messages',
              style: TextStyle(color: AppTheme.textMuted),
            ),
            const SizedBox(height: 4),
            Text(
              'Direct messages from mesh peers appear here',
              style: TextStyle(
                color: AppTheme.textMuted.withValues(alpha: 0.6),
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: peerIds.length,
      itemBuilder: (_, i) {
        final peerId = peerIds[i];
        final latest = messaging.getLatestDm(peerId);
        final unread = messaging.getUnreadCount(peerId);
        final peerName = messaging.getPeerName(peerId);

        return ListTile(
          leading: CircleAvatar(
            backgroundColor: AppTheme.cyan.withValues(alpha: 0.2),
            child: Text(
              peerName.isNotEmpty ? peerName[0].toUpperCase() : '?',
              style: const TextStyle(
                color: AppTheme.cyan,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          title: Text(
            peerName,
            style: TextStyle(
              color: AppTheme.textColor,
              fontWeight: unread > 0 ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
          subtitle: latest != null
              ? Text(
                  latest.body,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                )
              : null,
          trailing: unread > 0
              ? Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: AppTheme.emergencyRed,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '$unread',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                )
              : null,
          onTap: () {
            messaging.markThreadRead(peerId);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ConversationScreen(
                  peerId: peerId,
                  peerName: peerName,
                ),
              ),
            );
          },
        );
      },
    );
  }
}
