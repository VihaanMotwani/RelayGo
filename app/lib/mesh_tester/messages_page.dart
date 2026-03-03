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
    return Column(
      children: [
        // ── Segmented control ──
        Padding(
          padding: const EdgeInsets.fromLTRB(Spacing.md, Spacing.md, Spacing.md, Spacing.sm),
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
            child: _showReports ? _buildReportsList() : _buildMessagesList(),
          ),
        ),
      ],
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
      padding: const EdgeInsets.fromLTRB(Spacing.md, Spacing.sm, Spacing.md, Spacing.lg),
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
      padding: const EdgeInsets.fromLTRB(Spacing.md, Spacing.sm, Spacing.md, Spacing.lg),
      itemCount: _messages.length,
      separatorBuilder: (_, _) => const SizedBox(height: Spacing.sm),
      itemBuilder: (_, i) => _MessageCard(message: _messages[i])
          .animate()
          .fadeIn(duration: 200.ms, delay: (i * 30).ms)
          .slideY(begin: 0.1, end: 0, duration: 200.ms, curve: Curves.easeOut),
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
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
              style: theme.textTheme.bodyLarge?.copyWith(
                height: 1.4,
              ),
            ),
            const SizedBox(height: Spacing.md),
            // Bottom row: hops + source
            Row(
              children: [
                Icon(Icons.route_rounded, size: 14, color: theme.colorScheme.onSurface.withOpacity(0.4)),
                const SizedBox(width: 4),
                Text(
                  '${report.hops} hops',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
                const SizedBox(width: Spacing.md),
                Icon(Icons.device_hub_rounded, size: 14, color: theme.colorScheme.onSurface.withOpacity(0.4)),
                const SizedBox(width: 4),
                Text(
                  report.src.length > 8 ? report.src.substring(0, 8) : report.src,
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

  const _MessageCard({required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final time = DateTime.fromMillisecondsSinceEpoch(message.ts * 1000);
    final ago = _timeAgo(time);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: sender + badge + time
            Row(
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                  child: Text(
                    message.name.isNotEmpty ? message.name[0].toUpperCase() : '?',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: Spacing.sm),
                Text(
                  message.name,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: Spacing.sm),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: message.isBroadcast
                        ? Colors.blue.shade50
                        : Colors.green.shade50,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    message.isBroadcast ? 'Broadcast' : 'DM',
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: message.isBroadcast ? Colors.blue.shade700 : Colors.green.shade700,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  ago,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.4),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Spacing.sm),
            // Body
            Text(
              message.body,
              style: theme.textTheme.bodyMedium?.copyWith(
                height: 1.4,
              ),
            ),
            const SizedBox(height: Spacing.sm),
            // Hops
            Row(
              children: [
                Icon(Icons.route_rounded, size: 14, color: theme.colorScheme.onSurface.withOpacity(0.4)),
                const SizedBox(width: 4),
                Text(
                  '${message.hops} hops',
                  style: theme.textTheme.bodySmall?.copyWith(
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
