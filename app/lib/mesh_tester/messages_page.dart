import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../models/emergency_report.dart';
import '../models/mesh_message.dart';
import 'instrumented_mesh_service.dart';
import 'theme.dart';

class MessagesPage extends StatefulWidget {
  final InstrumentedMeshService mesh;

  const MessagesPage({super.key, required this.mesh});

  @override
  State<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends State<MessagesPage> {
  bool _showReports = true;
  List<EmergencyReport> _reports = [];
  List<MeshMessage> _messages = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didUpdateWidget(MessagesPage old) {
    super.didUpdateWidget(old);
    _loadData();
  }

  Future<void> _loadData() async {
    final reports = await widget.mesh.store.getAllReports();
    final messages = await widget.mesh.store.getAllMessages();
    if (mounted) {
      setState(() {
        _reports = reports;
        _messages = messages;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Column(
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
                        label: 'Reports',
                        count: _reports.length,
                        selected: _showReports,
                        onTap: () => setState(() => _showReports = true),
                      ),
                    ),
                    Expanded(
                      child: _SegmentButton(
                        label: 'Messages',
                        count: _messages.length,
                        selected: !_showReports,
                        onTap: () => setState(() => _showReports = false),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Content ──
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _showReports
                    ? _buildReportsList()
                    : _buildMessagesList(),
              ),
            ),
          ],
        ),

        // ── Floating Action Button (DMs) ──
        if (!_showReports)
          Positioned(
            bottom: Spacing.lg,
            right: Spacing.lg,
            child: FloatingActionButton.extended(
              onPressed: () => _showNewMessageSheet(context),
              icon: const Icon(Icons.send_rounded),
              label: const Text('Direct Message'),
            ).animate().scale(duration: 200.ms, curve: Curves.easeOutBack),
          ),
      ],
    );
  }

  void _showNewMessageSheet(BuildContext context) {
    String? selectedPeerId;
    if (widget.mesh.peers.isNotEmpty) {
      selectedPeerId = widget.mesh.peers.first.deviceId;
    }
    final textController = TextEditingController();
    bool isSending = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final theme = Theme.of(context);
            final peers = widget.mesh.peers;

            return Padding(
              padding: EdgeInsets.fromLTRB(
                Spacing.lg,
                Spacing.lg,
                Spacing.lg,
                MediaQuery.of(context).viewInsets.bottom + Spacing.lg,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'New Direct Message',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: Spacing.md),
                  if (peers.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(Spacing.md),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            color: Colors.orange.shade700,
                          ),
                          const SizedBox(width: Spacing.sm),
                          const Expanded(
                            child: Text(
                              'No peers discovered yet. Wait for a scan cycle (15s).',
                            ),
                          ),
                        ],
                      ),
                    )
                  else ...[
                    DropdownButtonFormField<String>(
                      value: selectedPeerId,
                      decoration: const InputDecoration(
                        labelText: 'To Peer',
                        border: OutlineInputBorder(),
                      ),
                      items: peers.map((p) {
                        return DropdownMenuItem(
                          value: p.deviceId,
                          child: Text(
                            '${p.displayName} (${p.deviceId.substring(0, 5)}...) RSSI: ${p.rssi}',
                          ),
                        );
                      }).toList(),
                      onChanged: (val) =>
                          setModalState(() => selectedPeerId = val),
                    ),
                    const SizedBox(height: Spacing.md),
                    TextField(
                      controller: textController,
                      maxLength: 100,
                      decoration: const InputDecoration(
                        labelText: 'Message (Max 100 chars)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: Spacing.md),
                    ValueListenableBuilder<TextEditingValue>(
                      valueListenable: textController,
                      builder: (context, textValue, _) {
                        return ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              vertical: Spacing.md,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed:
                              isSending ||
                                  selectedPeerId == null ||
                                  textValue.text.trim().isEmpty
                              ? null
                              : () async {
                                  setModalState(() => isSending = true);
                                  final msg = MeshMessage(
                                    ts:
                                        DateTime.now().millisecondsSinceEpoch ~/
                                        1000,
                                    src: widget.mesh.deviceId,
                                    name: widget.mesh.displayName,
                                    to: selectedPeerId,
                                    body: textValue.text.trim(),
                                  );
                                  final success = await widget.mesh
                                      .sendDirectMessage(selectedPeerId!, msg);

                                  if (context.mounted) {
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          success
                                              ? 'Message sent!'
                                              : 'Failed to send direct message.',
                                        ),
                                        backgroundColor: success
                                            ? Colors.green.shade600
                                            : Colors.red.shade600,
                                      ),
                                    );
                                  }
                                },
                          child: isSending
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Send Message'),
                        );
                      },
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildReportsList() {
    if (_reports.isEmpty) {
      return const _EmptyState(
        key: ValueKey('empty_reports'),
        icon: Icons.assignment_outlined,
        text: 'No reports yet.\nPreload data or receive via mesh.',
      );
    }
    return ListView.separated(
      key: const ValueKey('reports_list'),
      padding: const EdgeInsets.fromLTRB(
        Spacing.md,
        Spacing.sm,
        Spacing.md,
        Spacing.lg,
      ),
      itemCount: _reports.length,
      separatorBuilder: (_, _) => const SizedBox(height: Spacing.sm),
      itemBuilder: (_, i) => _ReportCard(report: _reports[i])
          .animate()
          .fadeIn(duration: 200.ms, delay: (i * 30).ms)
          .slideY(begin: 0.1, end: 0, duration: 200.ms, curve: Curves.easeOut),
    );
  }

  Widget _buildMessagesList() {
    if (_messages.isEmpty) {
      return const _EmptyState(
        key: ValueKey('empty_msgs'),
        icon: Icons.chat_bubble_outline_rounded,
        text: 'No messages yet.\nPreload data or receive via mesh.',
      );
    }
    return ListView.separated(
      key: const ValueKey('msgs_list'),
      padding: const EdgeInsets.fromLTRB(
        Spacing.md,
        Spacing.sm,
        Spacing.md,
        100, // Clear the FAB
      ),
      itemCount: _messages.length,
      separatorBuilder: (_, _) => const SizedBox(height: Spacing.sm),
      itemBuilder: (_, i) {
        final msg = _messages[_messages.length - 1 - i];
        final isMe = msg.src == widget.mesh.deviceId;
        return _MessageCard(message: msg, isMe: isMe)
            .animate()
            .fadeIn(
              duration: 200.ms,
              delay: ((_messages.length - 1 - i) * 30).ms,
            )
            .slideY(
              begin: 0.1,
              end: 0,
              duration: 200.ms,
              curve: Curves.easeOut,
            );
      },
    );
  }
}

// ── Segment Button ──

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
                    color: Colors.black.withOpacity(0.04),
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
                      : theme.colorScheme.onSurface.withOpacity(0.5),
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
                        ? theme.colorScheme.primary.withOpacity(0.1)
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

// ── Report Card ──

class _ReportCard extends StatelessWidget {
  final EmergencyReport report;

  const _ReportCard({required this.report});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _typeColor(report.type);
    final time = DateTime.fromMillisecondsSinceEpoch(report.ts * 1000);
    final ago = _timeAgo(time);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: type badge + time
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    report.type.toUpperCase(),
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ),
                const SizedBox(width: Spacing.sm),
                _UrgencyDots(urgency: report.urg),
                const Spacer(),
                Text(
                  ago,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.4),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Spacing.md),
            // Description
            Text(
              report.desc,
              style: theme.textTheme.bodyLarge?.copyWith(height: 1.4),
            ),
            const SizedBox(height: Spacing.md),
            // Bottom row: hops + source
            Row(
              children: [
                Icon(
                  Icons.route_rounded,
                  size: 14,
                  color: theme.colorScheme.onSurface.withOpacity(0.4),
                ),
                const SizedBox(width: 4),
                Text(
                  '${report.hops} hops',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
                const SizedBox(width: Spacing.md),
                Icon(
                  Icons.device_hub_rounded,
                  size: 14,
                  color: theme.colorScheme.onSurface.withOpacity(0.4),
                ),
                const SizedBox(width: 4),
                Text(
                  report.src.length > 8
                      ? report.src.substring(0, 8)
                      : report.src,
                  style: TextStyle(
                    fontFamily: 'RobotoMono',
                    fontSize: 12,
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static Color _typeColor(String type) {
    switch (type) {
      case 'fire':
        return Colors.red.shade600;
      case 'medical':
        return Colors.blue.shade600;
      case 'structural':
        return Colors.orange.shade600;
      case 'flood':
        return Colors.cyan.shade600;
      case 'hazmat':
        return Colors.purple.shade600;
      default:
        return Colors.grey.shade600;
    }
  }
}

// ── Urgency Dots ──

class _UrgencyDots extends StatelessWidget {
  final int urgency;

  const _UrgencyDots({required this.urgency});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final active = i < urgency;
        return Container(
          width: 6,
          height: 6,
          margin: const EdgeInsets.only(right: 3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active
                ? (urgency >= 4 ? Colors.red.shade500 : Colors.orange.shade500)
                : Colors.grey.shade200,
          ),
        );
      }),
    );
  }
}

// ── Message Card ──

class _MessageCard extends StatelessWidget {
  final MeshMessage message;
  final bool isMe;

  const _MessageCard({required this.message, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final time = DateTime.fromMillisecondsSinceEpoch(message.ts * 1000);
    final ago = _timeAgo(time);

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
          left: isMe ? 60 : 0,
          right: isMe ? 0 : 60,
          bottom: 2,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isMe
              ? theme.colorScheme.primary.withValues(alpha: 0.2)
              : theme.colorScheme.onSurface.withValues(alpha: 0.08),
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
            if (!isMe) ...[
              Text(
                message.name == 'User' || message.name == 'Unknown'
                    ? 'Device ${message.src.substring(0, 4).toUpperCase()}'
                    : message.name,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 2),
            ],
            Text(
              message.body,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.3),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!message.isBroadcast) ...[
                  Icon(
                    Icons.lock_rounded,
                    size: 10,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                  const SizedBox(width: 4),
                ],
                Text(
                  '$ago • ${message.hops} hops',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
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

// ── Empty State ──

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String text;

  const _EmptyState({super.key, required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(Spacing.lg),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 48, color: Colors.grey.shade400),
          ),
          const SizedBox(height: Spacing.md),
          Text(
            text,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.5),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms);
  }
}

// ── Helpers ──

String _timeAgo(DateTime time) {
  final diff = DateTime.now().difference(time);
  if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  return '${diff.inDays}d ago';
}
