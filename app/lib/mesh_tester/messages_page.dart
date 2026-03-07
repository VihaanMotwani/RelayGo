import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../models/directive.dart';
import '../models/mesh_message.dart';
import '../models/peer_info.dart';
import 'instrumented_mesh_service.dart';
import 'theme.dart';

// ────────────────────────────────────────────────────────────────────────────
// MessagesPage — top-level stateful widget
// ────────────────────────────────────────────────────────────────────────────

class MessagesPage extends StatefulWidget {
  final InstrumentedMeshService mesh;

  const MessagesPage({super.key, required this.mesh});

  @override
  State<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends State<MessagesPage> {
  bool _showDirectives = true;
  List<Directive> _directives = [];
  List<MeshMessage> _messages = [];

  // When non-null we're in the chat view for that peer.
  PeerInfo? _selectedPeer;

  StreamSubscription? _msgSub;
  StreamSubscription? _directiveSub;

  @override
  void initState() {
    super.initState();
    _loadData();
    _msgSub = widget.mesh.onNewMessage.listen((_) => _loadData());
    _directiveSub = widget.mesh.onNewDirective.listen((_) => _loadData());
  }

  @override
  void dispose() {
    _msgSub?.cancel();
    _directiveSub?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(MessagesPage old) {
    super.didUpdateWidget(old);
    _loadData();
  }

  Future<void> _loadData() async {
    final directives = await widget.mesh.store.getAllDirectives();
    final messages = await widget.mesh.store.getAllMessages();
    if (mounted) {
      setState(() {
        _directives = directives;
        _messages = messages;
      });
    }
  }

  void _openChat(PeerInfo peer) => setState(() => _selectedPeer = peer);
  void _closeChat() => setState(() => _selectedPeer = null);

  // Returns the messages for a conversation with a specific peer.
  // Outgoing: m.to == peerId (sent to this peer's BLE MAC)
  // Incoming: m.fromBleId == peerId (received from this peer's BLE MAC)
  List<MeshMessage> _messagesForPeer(String peerId) {
    final live = widget.mesh.messages;
    return live.where((m) => m.to == peerId || m.fromBleId == peerId).toList()
      ..sort((a, b) => a.ts.compareTo(b.ts));
  }

  // Returns the last message for preview in the peer list.
  MeshMessage? _lastMessageForPeer(String peerId) {
    final msgs = _messagesForPeer(peerId);
    return msgs.isEmpty ? null : msgs.last;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Segmented control ──
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Spacing.md,
            Spacing.md,
            Spacing.md,
            Spacing.sm,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.all(4),
            child: Row(
              children: [
                Expanded(
                  child: _SegmentButton(
                    label: 'Directives',
                    count: _directives.length,
                    selected: _showDirectives,
                    onTap: () {
                      setState(() {
                        _showDirectives = true;
                        _selectedPeer = null;
                      });
                    },
                  ),
                ),
                Expanded(
                  child: _SegmentButton(
                    label: 'Messages',
                    count: _messages.length,
                    selected: !_showDirectives,
                    onTap: () => setState(() {
                      _showDirectives = false;
                      _selectedPeer = null;
                    }),
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── Content ──
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            transitionBuilder: (child, anim) =>
                FadeTransition(opacity: anim, child: child),
            child: _showDirectives
                ? _buildDirectivesList()
                : _selectedPeer != null
                ? _ChatView(
                    key: ValueKey(_selectedPeer!.deviceId),
                    peer: _selectedPeer!,
                    mesh: widget.mesh,
                    messages: _messagesForPeer(_selectedPeer!.deviceId),
                    onBack: _closeChat,
                    onMessageSent: _loadData,
                  )
                : _PeerListView(
                    key: const ValueKey('peer_list'),
                    peers: widget.mesh.peers,
                    lastMessage: _lastMessageForPeer,
                    onPeerTap: _openChat,
                    noMessageYetCount: _messages.isEmpty,
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildDirectivesList() {
    // Merge live in-memory + loaded from DB (live takes precedence)
    final live = widget.mesh.directives;
    final all = live.isNotEmpty ? live : _directives;
    final sorted = List<Directive>.from(all)
      ..sort((a, b) => b.ts.compareTo(a.ts));

    if (sorted.isEmpty) {
      return const _EmptyState(
        key: ValueKey('empty_directives'),
        icon: Icons.campaign_outlined,
        text:
            'No directives yet.\nOperator instructions will appear here when the backend is reachable.',
        pulsing: false,
      );
    }
    return ListView.separated(
      key: const ValueKey('directives_list'),
      padding: const EdgeInsets.fromLTRB(
        Spacing.md,
        Spacing.sm,
        Spacing.md,
        Spacing.lg,
      ),
      itemCount: sorted.length,
      separatorBuilder: (_, __) => const SizedBox(height: Spacing.sm),
      itemBuilder: (_, i) => _DirectiveCard(directive: sorted[i])
          .animate()
          .fadeIn(duration: 200.ms, delay: (i * 30).ms)
          .slideY(begin: 0.08, end: 0, duration: 200.ms, curve: Curves.easeOut),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Peer List View
// ────────────────────────────────────────────────────────────────────────────

class _PeerListView extends StatelessWidget {
  final List<PeerInfo> peers;
  final MeshMessage? Function(String peerId) lastMessage;
  final void Function(PeerInfo) onPeerTap;
  final bool noMessageYetCount;

  const _PeerListView({
    super.key,
    required this.peers,
    required this.lastMessage,
    required this.onPeerTap,
    required this.noMessageYetCount,
  });

  @override
  Widget build(BuildContext context) {
    if (peers.isEmpty) {
      return const _EmptyState(
        key: ValueKey('empty_peers'),
        icon: Icons.bluetooth_searching_rounded,
        text: 'Waiting for peers…\nBLE scan runs every ~15s.',
        pulsing: true,
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.md,
        vertical: Spacing.sm,
      ),
      itemCount: peers.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, i) {
        final peer = peers[i];
        final msg = lastMessage(peer.deviceId);
        return _PeerCard(
              peer: peer,
              lastMessage: msg,
              onTap: () => onPeerTap(peer),
            )
            .animate()
            .fadeIn(duration: 200.ms, delay: (i * 40).ms)
            .slideX(
              begin: -0.05,
              end: 0,
              duration: 200.ms,
              curve: Curves.easeOut,
            );
      },
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Peer Card
// ────────────────────────────────────────────────────────────────────────────

class _PeerCard extends StatelessWidget {
  final PeerInfo peer;
  final MeshMessage? lastMessage;
  final VoidCallback onTap;

  const _PeerCard({
    required this.peer,
    required this.lastMessage,
    required this.onTap,
  });

  // Generate a consistent colour from a device ID
  Color _avatarColor(String deviceId) {
    final idx =
        deviceId.codeUnits.fold<int>(0, (a, b) => a + b) % _kColors.length;
    return _kColors[idx];
  }

  static const _kColors = [
    Color(0xFF5C6BC0),
    Color(0xFF26A69A),
    Color(0xFFEF5350),
    Color(0xFF42A5F5),
    Color(0xFFAB47BC),
    Color(0xFFFF7043),
    Color(0xFF66BB6A),
    Color(0xFFEC407A),
  ];

  String _peerLabel(PeerInfo p) {
    const genericNames = {'User', 'Unknown', 'RelayGo', ''};
    if (genericNames.contains(p.displayName.trim())) {
      return 'Device ${p.deviceId.substring(0, 4).toUpperCase()}';
    }
    return p.displayName;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = _peerLabel(peer);
    final initials = label.isNotEmpty ? label[0].toUpperCase() : '?';
    final avatarColor = _avatarColor(peer.deviceId);
    final online = peer.isRecent;
    final preview = lastMessage?.body ?? 'No messages yet';
    final time = lastMessage != null
        ? _timeAgo(DateTime.fromMillisecondsSinceEpoch(lastMessage!.ts * 1000))
        : '';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(
          children: [
            // Avatar + online dot
            Stack(
              clipBehavior: Clip.none,
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: avatarColor,
                  child: Text(
                    initials,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
                Positioned(
                  right: -1,
                  bottom: -1,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: online
                          ? Colors.green.shade500
                          : Colors.grey.shade400,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(width: 14),

            // Name + preview
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    preview,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.55,
                      ),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            // Time + chevron
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (time.isNotEmpty)
                  Text(
                    time,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                  ),
                const SizedBox(height: 4),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Chat View
// ────────────────────────────────────────────────────────────────────────────

class _ChatView extends StatefulWidget {
  final PeerInfo peer;
  final InstrumentedMeshService mesh;
  final List<MeshMessage> messages;
  final VoidCallback onBack;
  final VoidCallback onMessageSent;

  const _ChatView({
    super.key,
    required this.peer,
    required this.mesh,
    required this.messages,
    required this.onBack,
    required this.onMessageSent,
  });

  @override
  State<_ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<_ChatView> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isSending = false;

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(_ChatView old) {
    super.didUpdateWidget(old);
    // Scroll to bottom when messages change
    if (old.messages.length != widget.messages.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  String _peerLabel(PeerInfo p) {
    final name = p.displayName;
    if (name == 'User' || name == 'Unknown' || name.isEmpty) {
      return 'Device ${p.deviceId.substring(0, 4).toUpperCase()}';
    }
    return name;
  }

  Future<void> _sendMessage() async {
    final body = _textController.text.trim();
    if (body.isEmpty || _isSending) return;

    setState(() => _isSending = true);
    _textController.clear();

    final msg = MeshMessage(
      ts: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      src: widget.mesh.deviceId,
      name: widget.mesh.displayName,
      to: widget.peer.deviceId,
      body: body,
    );

    final success = await widget.mesh.sendDirectMessage(
      widget.peer.deviceId,
      msg,
    );
    widget.onMessageSent();

    if (mounted) {
      setState(() => _isSending = false);
      if (!success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Failed to send message. Is the peer still nearby?',
            ),
            backgroundColor: Colors.red.shade600,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = _peerLabel(widget.peer);
    final online = widget.peer.isRecent;

    return Column(
      children: [
        // ── Chat header (replaces AppBar within the Column) ──
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: Spacing.sm,
            vertical: Spacing.sm,
          ),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: Border(
              bottom: BorderSide(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
              ),
            ),
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                onPressed: widget.onBack,
              ),
              CircleAvatar(
                radius: 18,
                backgroundColor: theme.colorScheme.primary.withValues(
                  alpha: 0.15,
                ),
                child: Text(
                  label[0].toUpperCase(),
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: Spacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Row(
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          margin: const EdgeInsets.only(right: 4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: online
                                ? Colors.green.shade500
                                : Colors.grey.shade400,
                          ),
                        ),
                        Text(
                          online ? 'In range' : 'Out of range',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: online
                                ? Colors.green.shade600
                                : theme.colorScheme.onSurface.withValues(
                                    alpha: 0.4,
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // ── Message list ──
        Expanded(
          child: widget.messages.isEmpty
              ? Center(
                  child: Text(
                    'No messages yet.\nSay hello! 👋',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                  ),
                )
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(
                    Spacing.md,
                    Spacing.sm,
                    Spacing.md,
                    Spacing.sm,
                  ),
                  itemCount: widget.messages.length,
                  itemBuilder: (_, i) {
                    final msg = widget.messages[i];
                    final isMe = msg.src == widget.mesh.deviceId;
                    final showDateDivider =
                        i == 0 ||
                        _differentDay(widget.messages[i - 1].ts, msg.ts);
                    return Column(
                      children: [
                        if (showDateDivider) _DateDivider(ts: msg.ts),
                        _Bubble(message: msg, isMe: isMe)
                            .animate()
                            .fadeIn(duration: 150.ms)
                            .slideY(
                              begin: 0.05,
                              end: 0,
                              duration: 150.ms,
                              curve: Curves.easeOut,
                            ),
                      ],
                    );
                  },
                ),
        ),

        // ── Input bar ──
        _InputBar(
          controller: _textController,
          isSending: _isSending,
          onSend: _sendMessage,
        ),
      ],
    );
  }

  bool _differentDay(int prevTs, int nextTs) {
    final a = DateTime.fromMillisecondsSinceEpoch(prevTs * 1000);
    final b = DateTime.fromMillisecondsSinceEpoch(nextTs * 1000);
    return a.day != b.day || a.month != b.month || a.year != b.year;
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Input Bar
// ────────────────────────────────────────────────────────────────────────────

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool isSending;
  final VoidCallback onSend;

  const _InputBar({
    required this.controller,
    required this.isSending,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: EdgeInsets.fromLTRB(
        Spacing.md,
        Spacing.sm,
        Spacing.sm,
        Spacing.sm + MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              builder: (_, __, ___) => TextField(
                controller: controller,
                maxLength: 100,
                maxLines: 4,
                minLines: 1,
                buildCounter:
                    (
                      _, {
                      required currentLength,
                      required isFocused,
                      maxLength,
                    }) => null, // hide counter
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'Message…',
                  counterText: '',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: theme.colorScheme.onSurface.withValues(
                    alpha: 0.06,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                ),
                onSubmitted: (_) => onSend(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) {
              final canSend = value.text.trim().isNotEmpty && !isSending;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: canSend
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface.withValues(alpha: 0.12),
                ),
                child: IconButton(
                  icon: isSending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Icon(
                          Icons.send_rounded,
                          size: 18,
                          color: canSend ? Colors.white : Colors.grey.shade400,
                        ),
                  onPressed: canSend ? onSend : null,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Chat Bubble
// ────────────────────────────────────────────────────────────────────────────

class _Bubble extends StatelessWidget {
  final MeshMessage message;
  final bool isMe;

  const _Bubble({required this.message, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final time = DateTime.fromMillisecondsSinceEpoch(message.ts * 1000);
    final timeStr =
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
          left: isMe ? 56 : 0,
          right: isMe ? 0 : 56,
          bottom: 4,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isMe
              ? theme.colorScheme.primary.withValues(alpha: 0.18)
              : theme.colorScheme.onSurface.withValues(alpha: 0.07),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 16),
          ),
        ),
        child: Column(
          crossAxisAlignment: isMe
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Text(
              message.body,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.3),
            ),
            const SizedBox(height: 3),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$timeStr  •  ${message.hops} hop${message.hops == 1 ? '' : 's'}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Date Divider
// ────────────────────────────────────────────────────────────────────────────

class _DateDivider extends StatelessWidget {
  final int ts;
  const _DateDivider({required this.ts});

  @override
  Widget build(BuildContext context) {
    final dt = DateTime.fromMillisecondsSinceEpoch(ts * 1000);
    final now = DateTime.now();
    String label;
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      label = 'Today';
    } else {
      label = '${dt.day}/${dt.month}/${dt.year}';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          const Expanded(child: Divider()),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ),
          ),
          const Expanded(child: Divider()),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Segment Button
// ────────────────────────────────────────────────────────────────────────────

class _SegmentButton extends StatelessWidget {
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  const _SegmentButton({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : [],
        ),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: selected
                      ? theme.colorScheme.onSurface
                      : theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
              if (count > 0) ...[
                const SizedBox(width: Spacing.sm),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? theme.colorScheme.primary.withValues(alpha: 0.12)
                        : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$count',
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: selected
                          ? theme.colorScheme.primary
                          : Colors.grey.shade600,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Directive Card
// ────────────────────────────────────────────────────────────────────────────

class _DirectiveCard extends StatelessWidget {
  final Directive directive;

  const _DirectiveCard({required this.directive});

  static const _prioColors = {
    'high': Color(0xFFC83228),
    'medium': Color(0xFFC87800),
    'low': Color(0xFF2E7D32),
  };

  static const _prioBgColors = {
    'high': Color(0x0AC83228),
    'medium': Color(0x0AC87800),
    'low': Color(0x00000000),
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final prio = directive.priority.toLowerCase();
    final prioColor = _prioColors[prio] ?? _prioColors['medium']!;
    final prioBg = _prioBgColors[prio] ?? Colors.transparent;
    final ago = _timeAgo(directive.dateTime);

    return Card(
      color: prioBg,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Priority accent bar
            Container(
              width: 4,
              decoration: BoxDecoration(
                color: prioColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  bottomLeft: Radius.circular(12),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(Spacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top row: badges + time
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: prioColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            prio.toUpperCase(),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: prioColor,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                        if (directive.zone != null) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withValues(
                                alpha: 0.08,
                              ),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              directive.zone!.toUpperCase(),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                        const Spacer(),
                        Text(
                          ago,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: Spacing.sm),
                    // Sender name
                    Text(
                      directive.name.isNotEmpty
                          ? directive.name
                          : directive.src,
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Body
                    Text(
                      directive.body,
                      style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
                    ),
                    const SizedBox(height: Spacing.sm),
                    // Meta: TTL · hops
                    Row(
                      children: [
                        Icon(
                          Icons.timer_outlined,
                          size: 12,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.4,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'TTL ${directive.ttl}  •  ${directive.hops} hops',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.45,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Empty State
// ────────────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool pulsing;

  const _EmptyState({
    super.key,
    required this.icon,
    required this.text,
    this.pulsing = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final iconWidget = Container(
      padding: const EdgeInsets.all(Spacing.lg),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 48, color: Colors.grey.shade400),
    );

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          pulsing
              ? iconWidget
                    .animate(onPlay: (c) => c.repeat(reverse: true))
                    .fade(begin: 1, end: 0.4, duration: 1200.ms)
                    .scale(
                      begin: const Offset(1, 1),
                      end: const Offset(0.95, 0.95),
                      duration: 1200.ms,
                    )
              : iconWidget,
          const SizedBox(height: Spacing.md),
          Text(
            text,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms);
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Helpers
// ────────────────────────────────────────────────────────────────────────────

String _timeAgo(DateTime time) {
  final diff = DateTime.now().difference(time);
  if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  return '${diff.inDays}d ago';
}
