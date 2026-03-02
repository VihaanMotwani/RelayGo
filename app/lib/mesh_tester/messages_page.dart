import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

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
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.separator.withAlpha(80),
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.all(3),
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
          child: _showReports ? _buildReportsList() : _buildMessagesList(),
        ),
      ],
    );
  }

  Widget _buildReportsList() {
    if (_reports.isEmpty) {
      return _EmptyState(
        icon: Icons.assignment_outlined,
        text: 'No reports yet.\nPreload data or receive via mesh.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      itemCount: _reports.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _ReportCard(report: _reports[i])
          .animate()
          .fadeIn(duration: 200.ms, delay: (i * 50).ms),
    );
  }

  Widget _buildMessagesList() {
    if (_messages.isEmpty) {
      return _EmptyState(
        icon: Icons.chat_bubble_outline_rounded,
        text: 'No messages yet.\nPreload data or receive via mesh.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      itemCount: _messages.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _MessageCard(message: _messages[i])
          .animate()
          .fadeIn(duration: 200.ms, delay: (i * 50).ms),
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
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: Colors.black.withAlpha(10),
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
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: selected
                      ? AppColors.textPrimary
                      : AppColors.textTertiary,
                ),
              ),
              if (count > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.blue.withAlpha(20)
                        : AppColors.separator.withAlpha(120),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$count',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: selected
                          ? AppColors.blue
                          : AppColors.textTertiary,
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
    final color = _typeColor(report.type);
    final time = DateTime.fromMillisecondsSinceEpoch(report.ts * 1000);
    final ago = _timeAgo(time);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.separator.withAlpha(150)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: type badge + urgency + time
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withAlpha(20),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  report.type.toUpperCase(),
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _UrgencyDots(urgency: report.urg),
              const Spacer(),
              Text(ago, style: AppType.monoSmall()),
            ],
          ),
          const SizedBox(height: 10),
          // Description
          Text(
            report.desc,
            style: AppType.body(),
          ),
          const SizedBox(height: 8),
          // Bottom row: hops + source
          Row(
            children: [
              Icon(Icons.route_rounded, size: 13, color: AppColors.textTertiary),
              const SizedBox(width: 4),
              Text(
                '${report.hops} hops',
                style: AppType.monoSmall(),
              ),
              const SizedBox(width: 12),
              Icon(Icons.device_hub_rounded,
                  size: 13, color: AppColors.textTertiary),
              const SizedBox(width: 4),
              Text(
                report.src.length > 8
                    ? report.src.substring(0, 8)
                    : report.src,
                style: AppType.monoSmall(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static Color _typeColor(String type) {
    switch (type) {
      case 'fire':
        return AppColors.red;
      case 'medical':
        return AppColors.blue;
      case 'structural':
        return AppColors.orange;
      case 'flood':
        return const Color(0xFF5AC8FA); // iOS teal
      case 'hazmat':
        return AppColors.purple;
      default:
        return AppColors.textSecondary;
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
                ? (urgency >= 4 ? AppColors.red : AppColors.orange)
                : AppColors.separator,
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
    final time = DateTime.fromMillisecondsSinceEpoch(message.ts * 1000);
    final ago = _timeAgo(time);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.separator.withAlpha(150)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: sender + badge + time
          Row(
            children: [
              Text(
                message.name,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: message.isBroadcast
                      ? AppColors.blue.withAlpha(18)
                      : AppColors.green.withAlpha(18),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  message.isBroadcast ? 'Broadcast' : 'DM',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: message.isBroadcast
                        ? AppColors.blue
                        : AppColors.green,
                  ),
                ),
              ),
              const Spacer(),
              Text(ago, style: AppType.monoSmall()),
            ],
          ),
          const SizedBox(height: 8),
          // Body
          Text(message.body, style: AppType.body()),
          const SizedBox(height: 8),
          // Hops
          Row(
            children: [
              Icon(Icons.route_rounded,
                  size: 13, color: AppColors.textTertiary),
              const SizedBox(width: 4),
              Text('${message.hops} hops', style: AppType.monoSmall()),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Empty State ──

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String text;

  const _EmptyState({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: AppColors.separator),
          const SizedBox(height: 12),
          Text(
            text,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: AppColors.textTertiary,
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
